(in-package #:cl-stack-brotli)

;;; Load order: common → dec / enc (enc/dec link against common).

(define-foreign-library libbrotlicommon
  (:darwin (:or "libbrotlicommon.1.dylib" "libbrotlicommon.dylib"))
  (:unix (:or "libbrotlicommon.so.1" "libbrotlicommon.so"))
  (:windows (:or "brotlicommon.dll" "libbrotlicommon.dll"))
  (t (:default "libbrotlicommon")))

(define-foreign-library libbrotlidec
  (:darwin (:or "libbrotlidec.1.dylib" "libbrotlidec.dylib"))
  (:unix (:or "libbrotlidec.so.1" "libbrotlidec.so"))
  (:windows (:or "brotlidec.dll" "libbrotlidec.dll"))
  (t (:default "libbrotlidec")))

(define-foreign-library libbrotlienc
  (:darwin (:or "libbrotlienc.1.dylib" "libbrotlienc.dylib"))
  (:unix (:or "libbrotlienc.so.1" "libbrotlienc.so"))
  (:windows (:or "brotlienc.dll" "libbrotlienc.dll"))
  (t (:default "libbrotlienc")))

(defcenum brotli-decoder-result
  (:error 0)
  (:success 1)
  (:needs-more-input 2)
  (:needs-more-output 3))

(defcenum brotli-encoder-mode
  (:generic 0)
  (:text 1)
  (:font 2))

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
