(in-package #:cl-stack-brotli/tests)

(deftest decompressing-stream-round-trip
  (let* ((raw (%bytes "stream decompress via gray"))
         (enc (compress raw :quality 5)))
    (with-open-stream (src (make-octet-input-stream enc))
      (with-open-stream (in (make-decompressing-stream src))
        (ok (typep in 'brotli-decompressing-stream))
        (ok (equalp raw (%read-all in)))))))

(deftest compressing-stream-then-buffer-decode
  (let ((raw (%bytes "compressing stream output")))
    (with-open-stream (src (make-octet-input-stream raw))
      (with-open-stream (cin (make-compressing-stream src :quality 4))
        (ok (typep cin 'brotli-compressing-stream))
        (let ((enc (%read-all cin)))
          (ok (plusp (length enc)))
          (ok (equalp raw (decompress enc))))))))

(deftest stream-to-stream-round-trip
  (let ((raw (%bytes "pull compress then pull decompress")))
    (with-open-stream (plain (make-octet-input-stream raw))
      (with-open-stream (cin (make-compressing-stream plain :quality 3))
        (with-open-stream (din (make-decompressing-stream cin))
          (ok (equalp raw (%read-all din))))))))

(deftest decompressing-stream-large
  (let* ((raw (make-array 20000 :element-type '(unsigned-byte 8)
                          :initial-element 42))
         (enc (compress raw :quality 2)))
    (with-open-stream (src (make-octet-input-stream enc))
      (with-open-stream (in (make-decompressing-stream src))
        (ok (equalp raw (%read-all in 1024)))))))
