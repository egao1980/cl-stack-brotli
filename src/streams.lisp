(in-package #:cl-stack-brotli)

;;; Gray binary input streams over Brotli streaming C API.
;;; make-decompressing-stream: compressed source → plain bytes
;;; make-compressing-stream:   plain source → compressed bytes

(defclass brotli-stream (trivial-gray-streams:fundamental-binary-input-stream)
  ((source :initarg :source :reader brotli-stream-source)
   (state :initarg :state :accessor %bs-state)
   (fin :initarg :fin :reader %bs-fin)
   (fout :initarg :fout :reader %bs-fout)
   (fin-size :initarg :fin-size :reader %bs-fin-size)
   (fout-size :initarg :fout-size :reader %bs-fout-size)
   (fin-avail :initform 0 :accessor %bs-fin-avail)
   (fin-pos :initform 0 :accessor %bs-fin-pos)
   (fout-avail :initform 0 :accessor %bs-fout-avail)
   (fout-pos :initform 0 :accessor %bs-fout-pos)
   (source-eof :initform nil :accessor %bs-source-eof)
   (finished :initform nil :accessor %bs-finished)
   (closed :initform nil :accessor %bs-closed)))

(defclass brotli-decompressing-stream (brotli-stream) ())
(defclass brotli-compressing-stream (brotli-stream)
  ((op :initform :process :accessor %bcs-op)))

(defun %alloc-stream-buffers (&optional (in-size 4096) (out-size 8192))
  (values (foreign-alloc :uint8 :count in-size)
          (foreign-alloc :uint8 :count out-size)
          in-size out-size))

(defun make-decompressing-stream (source)
  "Return a binary input stream that decompresses octets read from SOURCE."
  (%load-native)
  (check-type source stream)
  (let ((state (%decoder-create (null-pointer) (null-pointer) (null-pointer))))
    (when (null-pointer-p state)
      (error 'brotli-error :message "BrotliDecoderCreateInstance failed"))
    (multiple-value-bind (fin fout fin-size fout-size) (%alloc-stream-buffers)
      (make-instance 'brotli-decompressing-stream
                     :source source :state state
                     :fin fin :fout fout
                     :fin-size fin-size :fout-size fout-size))))

(defun make-compressing-stream (source &key (quality 5) (lgwin 22) (mode :generic))
  "Return a binary input stream that compresses octets read from SOURCE."
  (%load-native)
  (check-type source stream)
  (check-type quality (integer 0 11))
  (let ((state (%encoder-create (null-pointer) (null-pointer) (null-pointer))))
    (when (null-pointer-p state)
      (error 'brotli-error :message "BrotliEncoderCreateInstance failed"))
    (%encoder-set-parameter state :quality quality)
    (%encoder-set-parameter state :lgwin lgwin)
    (%encoder-set-parameter state :mode
                            (ecase mode
                              (:generic 0) (:text 1) (:font 2)))
    (multiple-value-bind (fin fout fin-size fout-size) (%alloc-stream-buffers)
      (make-instance 'brotli-compressing-stream
                     :source source :state state
                     :fin fin :fout fout
                     :fin-size fin-size :fout-size fout-size))))

(defun %bs-close (stream destroy)
  (unless (%bs-closed stream)
    (setf (%bs-closed stream) t)
    (ignore-errors (funcall destroy (%bs-state stream)))
    (setf (%bs-state stream) (null-pointer))
    (foreign-free (%bs-fin stream))
    (foreign-free (%bs-fout stream)))
  t)

(defmethod close ((stream brotli-decompressing-stream) &key abort)
  (declare (ignore abort))
  (%bs-close stream #'%decoder-destroy))

(defmethod close ((stream brotli-compressing-stream) &key abort)
  (declare (ignore abort))
  (%bs-close stream #'%encoder-destroy))

(defun %bs-serve-byte (stream)
  (when (< (%bs-fout-pos stream) (%bs-fout-avail stream))
    (let ((b (mem-aref (%bs-fout stream) :uint8 (%bs-fout-pos stream))))
      (incf (%bs-fout-pos stream))
      b)))

(defun %bs-refill-input (stream)
  (when (and (zerop (- (%bs-fin-avail stream) (%bs-fin-pos stream)))
             (not (%bs-source-eof stream)))
    (let* ((lisp (make-array (%bs-fin-size stream) :element-type '(unsigned-byte 8)))
           (n (read-sequence lisp (brotli-stream-source stream))))
      (when (zerop n)
        (setf (%bs-source-eof stream) t)
        (return-from %bs-refill-input 0))
      (dotimes (i n)
        (setf (mem-aref (%bs-fin stream) :uint8 i) (aref lisp i)))
      (setf (%bs-fin-pos stream) 0
            (%bs-fin-avail stream) n)
      n)))

(defun %bds-pump (stream)
  "Produce more decompressed output into fout. Returns T if progress/EOF settled."
  (when (%bs-finished stream)
    (return-from %bds-pump t))
  (loop
    (when (< (%bs-fout-pos stream) (%bs-fout-avail stream))
      (return t))
    (%bs-refill-input stream)
    (with-foreign-objects ((avail-in :size)
                           (next-in :pointer)
                           (avail-out :size)
                           (next-out :pointer)
                           (total-out :size))
      (let* ((in-left (- (%bs-fin-avail stream) (%bs-fin-pos stream)))
             (in-ptr (inc-pointer (%bs-fin stream) (%bs-fin-pos stream))))
        (setf (mem-ref avail-in :size) in-left
              (mem-ref next-in :pointer) (if (plusp in-left) in-ptr (null-pointer))
              (mem-ref avail-out :size) (%bs-fout-size stream)
              (mem-ref next-out :pointer) (%bs-fout stream)
              (mem-ref total-out :size) 0)
        (let ((res (%decoder-decompress-stream
                    (%bs-state stream) avail-in next-in avail-out next-out total-out)))
          (let ((consumed (- in-left (mem-ref avail-in :size)))
                (produced (- (%bs-fout-size stream) (mem-ref avail-out :size))))
            (incf (%bs-fin-pos stream) consumed)
            (setf (%bs-fout-pos stream) 0
                  (%bs-fout-avail stream) produced)
            (ecase res
              (:success
               (setf (%bs-finished stream) t)
               (return t))
              (:needs-more-output
               (when (plusp produced) (return t)))
              (:needs-more-input
               (when (%bs-source-eof stream)
                 (error 'brotli-error :message "truncated Brotli stream"))
               (when (plusp produced) (return t)))
              (:error
               (error 'brotli-error :message "BrotliDecoderDecompressStream failed")))))))))

(defun %bcs-pump (stream)
  (when (%bs-finished stream)
    (return-from %bcs-pump t))
  (loop
    (when (< (%bs-fout-pos stream) (%bs-fout-avail stream))
      (return t))
    (when (and (eq (%bcs-op stream) :process)
               (zerop (- (%bs-fin-avail stream) (%bs-fin-pos stream))))
      (%bs-refill-input stream)
      (when (%bs-source-eof stream)
        (setf (%bcs-op stream) :finish)))
    (with-foreign-objects ((avail-in :size)
                           (next-in :pointer)
                           (avail-out :size)
                           (next-out :pointer)
                           (total-out :size))
      (let* ((in-left (- (%bs-fin-avail stream) (%bs-fin-pos stream)))
             (in-ptr (inc-pointer (%bs-fin stream) (%bs-fin-pos stream)))
             (op (%bcs-op stream)))
        (setf (mem-ref avail-in :size) in-left
              (mem-ref next-in :pointer) (if (plusp in-left) in-ptr (null-pointer))
              (mem-ref avail-out :size) (%bs-fout-size stream)
              (mem-ref next-out :pointer) (%bs-fout stream)
              (mem-ref total-out :size) 0)
        (unless (plusp (%encoder-compress-stream
                        (%bs-state stream) op avail-in next-in avail-out next-out total-out))
          (error 'brotli-error :message "BrotliEncoderCompressStream failed"))
        (let ((consumed (- in-left (mem-ref avail-in :size)))
              (produced (- (%bs-fout-size stream) (mem-ref avail-out :size))))
          (incf (%bs-fin-pos stream) consumed)
          (setf (%bs-fout-pos stream) 0
                (%bs-fout-avail stream) produced)
          (when (and (eq op :finish)
                     (zerop (mem-ref avail-in :size))
                     (zerop (%encoder-has-more-output (%bs-state stream)))
                     (plusp (%encoder-is-finished (%bs-state stream))))
            (setf (%bs-finished stream) t))
          (when (or (plusp produced) (%bs-finished stream))
            (return t)))))))

(defmethod trivial-gray-streams:stream-read-byte ((stream brotli-decompressing-stream))
  (or (%bs-serve-byte stream)
      (progn (%bds-pump stream)
             (or (%bs-serve-byte stream) :eof))))

(defmethod trivial-gray-streams:stream-read-byte ((stream brotli-compressing-stream))
  (or (%bs-serve-byte stream)
      (progn (%bcs-pump stream)
             (or (%bs-serve-byte stream) :eof))))

(defun %bs-read-sequence (stream seq start end pump)
  (let ((i start))
    (loop while (< i end)
          do (let ((b (or (%bs-serve-byte stream)
                          (progn (funcall pump stream)
                                 (%bs-serve-byte stream)))))
               (unless b (return i))
               (setf (aref seq i) b)
               (incf i)))
    i))

(defmethod trivial-gray-streams:stream-read-sequence
    ((stream brotli-decompressing-stream) seq start end &key)
  (%bs-read-sequence stream seq start end #'%bds-pump))

(defmethod trivial-gray-streams:stream-read-sequence
    ((stream brotli-compressing-stream) seq start end &key)
  (%bs-read-sequence stream seq start end #'%bcs-pump))
