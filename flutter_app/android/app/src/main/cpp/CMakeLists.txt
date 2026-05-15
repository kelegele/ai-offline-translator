cmake_minimum_required(VERSION 3.18.1)

project(translator_engine)

set(LLAMA_CPP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../third_party/llama.cpp")

add_library(translator_jni SHARED
    translator_jni.cpp
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../../native/translator_engine/translator_engine.cpp
)

target_include_directories(translator_jni PRIVATE
    ${LLAMA_CPP_DIR}/include
    ${LLAMA_CPP_DIR}/common
    ${LLAMA_CPP_DIR}/vendor
    ${LLAMA_CPP_DIR}/ggml/include
    ${CMAKE_CURRENT_SOURCE_DIR}/../../../../native/translator_engine
)

# Link pre-built llama.cpp static libs
add_library(lllama STATIC IMPORTED)
set_target_properties(lllama PROPERTIES
    IMPORTED_LOCATION ${LLAMA_CPP_DIR}/build-android/${ANDROID_ABI}/src/libllama.a)

add_library(llama-common STATIC IMPORTED)
set_target_properties(llama-common PROPERTIES
    IMPORTED_LOCATION ${LLAMA_CPP_DIR}/build-android/${ANDROID_ABI}/common/libllama-common.a)

add_library(llama-common-base STATIC IMPORTED)
set_target_properties(llama-common-base PROPERTIES
    IMPORTED_LOCATION ${LLAMA_CPP_DIR}/build-android/${ANDROID_ABI}/common/libllama-common-base.a)

add_library(ggml STATIC IMPORTED)
set_target_properties(ggml PROPERTIES
    IMPORTED_LOCATION ${LLAMA_CPP_DIR}/build-android/${ANDROID_ABI}/ggml/src/libggml.a)

add_library(ggml-cpu STATIC IMPORTED)
set_target_properties(ggml-cpu PROPERTIES
    IMPORTED_LOCATION ${LLAMA_CPP_DIR}/build-android/${ANDROID_ABI}/ggml/src/libggml-cpu.a)

add_library(ggml-base STATIC IMPORTED)
set_target_properties(ggml-base PROPERTIES
    IMPORTED_LOCATION ${LLAMA_CPP_DIR}/build-android/${ANDROID_ABI}/ggml/src/libggml-base.a)

target_link_libraries(translator_jni
    lllama llama-common llama-common-base ggml ggml-cpu ggml-base
    log
)

target_compile_features(translator_jni PRIVATE cxx_std_17)
