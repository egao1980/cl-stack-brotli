(in-package #:cl-stack-brotli)

;; defparameter: SBCL DEFCONSTANT on strings trips DEFCONSTANT-UNEQL on reload.
(defparameter +brotli-version+ "1.2.1"
  "Brotli release this package version tracks (must match ASDF :version / OCI tag).")

(define-condition brotli-error (error)
  ((message :initarg :message :reader brotli-error-message))
  (:report (lambda (c s)
             (format s "Brotli error: ~A" (brotli-error-message c)))))

(defun %octet-vector (octets)
  (etypecase octets
    ((simple-array (unsigned-byte 8) (*)) octets)
    ((vector (unsigned-byte 8))
     (make-array (length octets) :element-type '(unsigned-byte 8) :initial-contents octets))))

(defun compress (octets &key (quality 11) (mode :generic) (lgwin 22))
  "Compress OCTETS with Brotli. QUALITY 0..11 (default 11). Returns (unsigned-byte 8) vector."
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
          (dotimes (i n)
            (setf (aref result i) (mem-aref out :uint8 i)))
          result)))))

(defun decompress (octets)
  "Decompress Brotli OCTETS. Returns (unsigned-byte 8) vector.
   Uses the streaming decoder — one-shot BrotliDecoderDecompress maps
   NEEDS_MORE_OUTPUT to ERROR, so growing a one-shot buffer is unreliable."
  (let* ((in (%octet-vector octets))
         (in-len (length in))
         (state (%decoder-create (null-pointer) (null-pointer) (null-pointer))))
    (when (null-pointer-p state)
      (error 'brotli-error :message "BrotliDecoderCreateInstance failed"))
    (unwind-protect
         (let* ((chunk (max 4096 (* 4 (max in-len 1))))
                (out (foreign-alloc :uint8 :count chunk))
                (result (make-array 0 :element-type '(unsigned-byte 8)
                                       :adjustable t :fill-pointer 0)))
           (unwind-protect
                (with-pointer-to-vector-data (in-ptr in)
                  (with-foreign-objects ((avail-in :size)
                                         (next-in :pointer)
                                         (avail-out :size)
                                         (next-out :pointer)
                                         (total-out :size))
                    (setf (mem-ref avail-in :size) in-len
                          (mem-ref next-in :pointer)
                          (if (plusp in-len) in-ptr (null-pointer)))
                    (loop
                      (setf (mem-ref avail-out :size) chunk
                            (mem-ref next-out :pointer) out
                            (mem-ref total-out :size) 0)
                      (let ((res (%decoder-decompress-stream
                                  state avail-in next-in avail-out next-out total-out)))
                        (let ((produced (- chunk (mem-ref avail-out :size))))
                          (dotimes (i produced)
                            (vector-push-extend (mem-aref out :uint8 i) result))
                          (ecase res
                            (:success
                             (return
                               (coerce result '(simple-array (unsigned-byte 8) (*)))))
                            (:needs-more-output
                             ;; keep looping with same input remainder
                             )
                            (:needs-more-input
                             (error 'brotli-error
                                    :message "truncated Brotli stream"))
                            (:error
                             (error 'brotli-error
                                    :message "BrotliDecoderDecompressStream failed"))))))))
             (foreign-free out)))
      (%decoder-destroy state))))
