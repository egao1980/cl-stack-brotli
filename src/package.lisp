(defpackage #:cl-stack-brotli
  (:use #:cl #:cffi)
  (:export #:+brotli-version+
           #:brotli-error
           #:ensure-brotli
           #:compress
           #:decompress))
