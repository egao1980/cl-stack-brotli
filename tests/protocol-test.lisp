(in-package #:cl-stack-brotli/tests)

(deftest protocol-br-roundtrip
  (let* ((raw (%bytes "hello compression-protocol br"))
         (enc (compression-protocol:compress raw :algorithm :br :level 5))
         (dec (compression-protocol:decompress enc :algorithm :br)))
    (ok (plusp (length enc)))
    (ok (equalp raw dec))))
