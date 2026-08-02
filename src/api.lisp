(in-package #:cl-stack-brotli)

;; defparameter: SBCL DEFCONSTANT on strings trips DEFCONSTANT-UNEQL on reload.
(defparameter +brotli-version+ "1.2.0"
  "Brotli release this package version tracks (must match ASDF :version / OCI tag).")

(define-condition brotli-error (error)
  ((message :initarg :message :reader brotli-error-message))
  (:report (lambda (c s)
             (format s "Brotli error: ~A" (brotli-error-message c)))))

(defvar *brotli-loaded* nil)

(defun %host-os ()
  #+windows "windows"
  #+darwin "darwin"
  #+linux "linux"
  #-(or windows darwin linux) "unknown")

(defun %host-arch ()
  #+(or x86-64 x64) "amd64"
  #+(or arm64 aarch64) "arm64"
  #-(or x86-64 x64 arm64 aarch64) "unknown")

(defun %native-search-dirs ()
  "Overlay native/ (OCI) and lib/<os>-<arch>/ (local build). No LD_LIBRARY_PATH."
  (let ((dirs '()))
    (let ((v (uiop:getenv "CL_STACK_BROTLI_NATIVE")))
      (when (and v (plusp (length v)))
        (push v dirs)))
    (ignore-errors
      (let* ((sys (asdf:find-system :cl-stack-brotli nil))
             (root (when sys (asdf:system-source-directory sys))))
        (when root
          (push (namestring (merge-pathnames "native/" root)) dirs)
          (push (namestring
                 (merge-pathnames (format nil "lib/~A-~A/" (%host-os) (%host-arch)) root))
                dirs))))
    (nreverse dirs)))

(defun %lib-candidates (base)
  "Filenames to try under a native dir for BASE (e.g. \"libbrotlicommon\")."
  #+windows
  (list (format nil "~A.dll" (subseq base 3)) ; brotlicommon.dll
        (format nil "~A.dll" base)
        (format nil "lib~A.dll" (subseq base 3)))
  #+darwin
  (list (format nil "~A.dylib" base)
        (format nil "~A.1.dylib" base))
  #+(and unix (not darwin))
  (list (format nil "~A.so" base)
        (format nil "~A.so.1" base))
  #-(or windows darwin unix)
  (list (format nil "~A.so" base)))

(defun %find-lib (dir base)
  (dolist (name (%lib-candidates base))
    (let ((p (merge-pathnames name (uiop:ensure-directory-pathname dir))))
      (when (probe-file p)
        (return (namestring (truename p)))))))

(defun %absolute-preload (dir)
  "Load common → dec → enc by absolute path (cl-repository post-install policy)."
  (let ((paths (mapcar (lambda (b) (%find-lib dir b))
                       '("libbrotlicommon" "libbrotlidec" "libbrotlienc"))))
    (when (every #'identity paths)
      (dolist (p paths)
        (load-foreign-library p))
      t)))

(defun %load-native ()
  "Load libbrotli* via CFFI search path / absolute preload (not LD_LIBRARY_PATH).
   Invoked at ASDF load — consumers just call COMPRESS / DECOMPRESS."
  (unless *brotli-loaded*
    (let ((preloaded nil))
      (dolist (dir (%native-search-dirs))
        (when (and dir (uiop:directory-exists-p dir))
          (pushnew dir cffi:*foreign-library-directories* :test #'equal)
          (unless preloaded
            (setf preloaded (%absolute-preload dir)))))
      (unless preloaded
        (load-foreign-library 'libbrotlicommon)
        (load-foreign-library 'libbrotlidec)
        (load-foreign-library 'libbrotlienc)))
    (setf *brotli-loaded* t))
  (values t +brotli-version+))

(defun %octet-vector (octets)
  (etypecase octets
    ((simple-array (unsigned-byte 8) (*)) octets)
    ((vector (unsigned-byte 8))
     (make-array (length octets) :element-type '(unsigned-byte 8) :initial-contents octets))))

(defun compress (octets &key (quality 11) (mode :generic) (lgwin 22))
  "Compress OCTETS with Brotli. QUALITY 0..11 (default 11). Returns (unsigned-byte 8) vector."
  (%load-native)
  (check-type quality (integer 0 11))
  (let* ((in (%octet-vector octets))
         (in-len (length in))
         (max (%encoder-max-compressed-size in-len)))
    (when (zerop max)
      (error 'brotli-error :message "BrotliEncoderMaxCompressedSize returned 0"))
    (with-foreign-object (out-size :size)
      (setf (mem-ref out-size :size) max)
      (with-foreign-object (out :uint8 max)
        (with-pointer-to-vector-data (in-ptr in)
          (unless (plusp (%encoder-compress quality lgwin mode in-len in-ptr out-size out))
            (error 'brotli-error :message "BrotliEncoderCompress failed")))
        (let* ((n (mem-ref out-size :size))
               (result (make-array n :element-type '(unsigned-byte 8))))
          (loop for i below n do (setf (aref result i) (mem-aref out :uint8 i)))
          result)))))

(defun decompress (octets)
  "Decompress Brotli OCTETS. Returns (unsigned-byte 8) vector."
  (%load-native)
  (let* ((in (%octet-vector octets))
         (in-len (length in))
         (state (%decoder-create (null-pointer) (null-pointer) (null-pointer))))
    (when (null-pointer-p state)
      (error 'brotli-error :message "BrotliDecoderCreateInstance failed"))
    (unwind-protect
         (with-foreign-objects ((avail-in :size)
                                (next-in :pointer)
                                (avail-out :size)
                                (next-out :pointer)
                                (total-out :size))
           (with-pointer-to-vector-data (in-ptr in)
             (setf (mem-ref avail-in :size) in-len
                   (mem-ref next-in :pointer) in-ptr
                   (mem-ref total-out :size) 0)
             (let ((cap (max 1024 (* 4 in-len)))
                   (chunks nil))
               (loop
                 (with-foreign-object (out :uint8 cap)
                   (setf (mem-ref avail-out :size) cap
                         (mem-ref next-out :pointer) out)
                   (let ((res (%decoder-decompress-stream
                               state avail-in next-in avail-out next-out total-out)))
                     (let* ((produced (- cap (mem-ref avail-out :size)))
                            (chunk (make-array produced :element-type '(unsigned-byte 8))))
                       (loop for i below produced
                             do (setf (aref chunk i) (mem-aref out :uint8 i)))
                       (push chunk chunks))
                     (ecase res
                       (:success
                        (return
                          (let* ((parts (nreverse chunks))
                                 (total (reduce #'+ parts :key #'length))
                                 (result (make-array total :element-type '(unsigned-byte 8)))
                                 (off 0))
                            (dolist (p parts)
                              (replace result p :start1 off)
                              (incf off (length p)))
                            result)))
                       (:needs-more-output
                        (setf cap (* 2 cap)))
                       (:needs-more-input
                        (error 'brotli-error :message "truncated Brotli input"))
                       (:error
                        (error 'brotli-error :message "BrotliDecoderDecompressStream failed"))))))))
      (%decoder-destroy state))))
