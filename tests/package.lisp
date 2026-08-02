(defpackage #:cl-stack-brotli/tests
  (:use #:cl #:rove #:cl-stack-brotli)
  (:import-from #:trivial-gray-streams
                #:fundamental-binary-input-stream
                #:stream-read-byte
                #:stream-read-sequence))

(in-package #:cl-stack-brotli/tests)

(defclass octet-input-stream (fundamental-binary-input-stream)
  ((data :initarg :data :reader oid-data)
   (pos :initform 0 :accessor oid-pos)))

(defun make-octet-input-stream (octets)
  (make-instance 'octet-input-stream
                 :data (coerce octets '(simple-array (unsigned-byte 8) (*)))))

(defmethod stream-read-byte ((s octet-input-stream))
  (let ((pos (oid-pos s))
        (data (oid-data s)))
    (if (>= pos (length data))
        :eof
        (prog1 (aref data pos)
          (incf (oid-pos s))))))

(defmethod stream-read-sequence ((s octet-input-stream) seq start end &key)
  (let* ((data (oid-data s))
         (pos (oid-pos s))
         (n (min (- end start) (- (length data) pos))))
    (replace seq data :start1 start :end1 (+ start n) :start2 pos)
    (incf (oid-pos s) n)
    (+ start n)))

(defun %bytes (string)
  (map '(simple-array (unsigned-byte 8) (*)) #'char-code string))

(defun %read-all (stream &optional (chunk 4096))
  (let ((out (make-array 0 :element-type '(unsigned-byte 8)
                            :adjustable t :fill-pointer 0))
        (buf (make-array chunk :element-type '(unsigned-byte 8))))
    (loop for n = (read-sequence buf stream)
          while (plusp n)
          do (loop for i below n do (vector-push-extend (aref buf i) out)))
    (coerce out '(simple-array (unsigned-byte 8) (*)))))
