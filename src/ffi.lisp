(in-package #:cl-stack-brotli)

(defcenum brotli-decoder-result
  (:error 0)
  (:success 1)
  (:needs-more-input 2)
  (:needs-more-output 3))

(defcenum brotli-encoder-mode
  (:generic 0)
  (:text 1)
  (:font 2))

(defcenum brotli-encoder-operation
  (:process 0)
  (:flush 1)
  (:finish 2)
  (:emit-metadata 3))

(defcenum brotli-encoder-parameter
  (:mode 0)
  (:quality 1)
  (:lgwin 2)
  (:lgblock 3)
  (:disable-literal-context-modeling 4)
  (:size-hint 5)
  (:large-window 6))

;;; --- one-shot ---

(defcfun ("BrotliEncoderMaxCompressedSize" %encoder-max-compressed-size) :size
  (input-size :size))

(defcfun ("BrotliEncoderCompress" %encoder-compress) :int
  (quality :int)
  (lgwin :int)
  (mode brotli-encoder-mode)
  (input-size :size)
  (input :pointer)
  (encoded-size (:pointer :size))
  (encoded :pointer))

(defcfun ("BrotliDecoderDecompress" %decoder-decompress) brotli-decoder-result
  (encoded-size :size)
  (encoded :pointer)
  (decoded-size (:pointer :size))
  (decoded :pointer))

;;; --- streaming decode ---

(defcfun ("BrotliDecoderCreateInstance" %decoder-create) :pointer
  (alloc :pointer)
  (free :pointer)
  (opaque :pointer))

(defcfun ("BrotliDecoderDestroyInstance" %decoder-destroy) :void
  (state :pointer))

(defcfun ("BrotliDecoderDecompressStream" %decoder-decompress-stream) brotli-decoder-result
  (state :pointer)
  (available-in (:pointer :size))
  (next-in (:pointer :pointer))
  (available-out (:pointer :size))
  (next-out (:pointer :pointer))
  (total-out (:pointer :size)))

;;; --- streaming encode ---

(defcfun ("BrotliEncoderCreateInstance" %encoder-create) :pointer
  (alloc :pointer)
  (free :pointer)
  (opaque :pointer))

(defcfun ("BrotliEncoderDestroyInstance" %encoder-destroy) :void
  (state :pointer))

(defcfun ("BrotliEncoderSetParameter" %encoder-set-parameter) :int
  (state :pointer)
  (param brotli-encoder-parameter)
  (value :uint32))

(defcfun ("BrotliEncoderCompressStream" %encoder-compress-stream) :int
  (state :pointer)
  (op brotli-encoder-operation)
  (available-in (:pointer :size))
  (next-in (:pointer :pointer))
  (available-out (:pointer :size))
  (next-out (:pointer :pointer))
  (total-out (:pointer :size)))

(defcfun ("BrotliEncoderIsFinished" %encoder-is-finished) :int
  (state :pointer))

(defcfun ("BrotliEncoderHasMoreOutput" %encoder-has-more-output) :int
  (state :pointer))
