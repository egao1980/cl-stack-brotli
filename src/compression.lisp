(in-package #:cl-stack-brotli)

(defun %protocol-octets (data)
  (compression-protocol::%ensure-octets data))

(defun %as-compression-error (algorithm condition)
  (error 'compression-protocol:compression-error
         :algorithm algorithm
         :message (or (ignore-errors (brotli-error-message condition))
                      (princ-to-string condition))))

(macrolet ((define-br-codec (algorithm)
             `(progn
                (defmethod compression-protocol:compress-using-algorithm
                    ((algorithm (eql ,algorithm)) data &key level)
                  (handler-case
                      (compress (%protocol-octets data) :quality (or level 11))
                    (brotli-error (c)
                      (%as-compression-error ,algorithm c))))
                (defmethod compression-protocol:decompress-using-algorithm
                    ((algorithm (eql ,algorithm)) data &key)
                  (handler-case
                      (decompress (%protocol-octets data))
                    (brotli-error (c)
                      (%as-compression-error ,algorithm c))))
                (defmethod compression-protocol:make-decompressing-stream-using-algorithm
                    ((algorithm (eql ,algorithm)) input &key)
                  (handler-case
                      (make-decompressing-stream input)
                    (brotli-error (c)
                      (%as-compression-error ,algorithm c)))))))
  (define-br-codec :br)
  (define-br-codec :brotli))
