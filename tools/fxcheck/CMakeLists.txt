# fxcheck: compiles .fx effects with ReShade's own effect compiler, so CI catches errors before ReShade does.
# Linux only. The compiler sources are pinned to ReShade v6.8.0 (the same files and hashes Unishade's posix.cmake uses).
cmake_minimum_required(VERSION 3.20)
project(fxcheck LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

function(fetch_file url hash destination)
    if(NOT EXISTS "${destination}")
        file(DOWNLOAD "${url}" "${destination}.part" EXPECTED_HASH "SHA256=${hash}" STATUS status)
        list(GET status 0 code)
        if(NOT code EQUAL 0)
            file(REMOVE "${destination}.part")
            list(GET status 1 message)
            message(FATAL_ERROR "Could not download ${url}: ${message}")
        endif()
        file(RENAME "${destination}.part" "${destination}")
    endif()
endfunction()

set(FX "${CMAKE_BINARY_DIR}/reshadefx")
set(FX_URL "https://raw.githubusercontent.com/crosire/reshade/v6.8.0/source")
fetch_file("${FX_URL}/effect_codegen.hpp" 5eab66de38d61b8cf8ef036085e2914a0d20c81691bd9691229d95532e3bc532 "${FX}/effect_codegen.hpp")
fetch_file("${FX_URL}/effect_codegen_hlsl.cpp" 294b2f9961dec5034065979bd7100eb77465b2f8c54140bc82b957719a498c73 "${FX}/effect_codegen_hlsl.cpp")
fetch_file("${FX_URL}/effect_codegen_spirv.cpp" ac90b11eb9d3c917aa5ee4b6129b141e624c255e7fdecc0251c176db4e9165eb "${FX}/effect_codegen_spirv.cpp")
fetch_file("${FX_URL}/effect_expression.cpp" e41ac27190d9eb30e2227f5ae2d205e6b32708e08d0044e44937e4c757435662 "${FX}/effect_expression.cpp")
fetch_file("${FX_URL}/effect_expression.hpp" 7f652ce4af688ef7c1a16bfda251a855ad8c0b9dbea5e85047a28bedf50d2c34 "${FX}/effect_expression.hpp")
fetch_file("${FX_URL}/effect_lexer.cpp" 03612358eb582d77b185bb3c5379e9cb54deaf076a6d0ec6d797d2b018b9427b "${FX}/effect_lexer.cpp")
fetch_file("${FX_URL}/effect_lexer.hpp" 80d464c306678c8029c4185a593f2d7d6261f135dbb5f892554b29625e896f10 "${FX}/effect_lexer.hpp")
fetch_file("${FX_URL}/effect_module.hpp" 383e91286d8351ebb62ed7b500aced349fbbfba205cb65917473842ced6a01c7 "${FX}/effect_module.hpp")
fetch_file("${FX_URL}/effect_parser.hpp" c708941973667946c89de3e0f4f257badfc1e79f297edc5494de88b2729cabcd "${FX}/effect_parser.hpp")
fetch_file("${FX_URL}/effect_parser_exp.cpp" 8bea9ec2b0abb1982fe561cadae3b8c04e5d46fe8712684144301fc74206709c "${FX}/effect_parser_exp.cpp")
fetch_file("${FX_URL}/effect_parser_stmt.cpp" 5ebfa9ed1784ad6bd3f8eaeac88e0d6308d0777ba3ad3841e720a8f7fb86cfb3 "${FX}/effect_parser_stmt.cpp")
fetch_file("${FX_URL}/effect_preprocessor.cpp" 9137b441bd7b111fa6067f0a2eef510193d2f45441e2588965ea09596565a863 "${FX}/effect_preprocessor.cpp")
fetch_file("${FX_URL}/effect_preprocessor.hpp" 265a25de71e6ed96db4fd1c8fc2831c588969dc5a57a8305a869b5dc85465357 "${FX}/effect_preprocessor.hpp")
fetch_file("${FX_URL}/effect_symbol_table.cpp" d94dfbef056dad76043288f2e8894efc9b9c3bce3010720ccf6dada558442a49 "${FX}/effect_symbol_table.cpp")
fetch_file("${FX_URL}/effect_symbol_table.hpp" ab1e4eaed12469b2aa3669375044f82c16efc5257b1e27d03b3796eb915e94ce "${FX}/effect_symbol_table.hpp")
fetch_file("${FX_URL}/effect_symbol_table_intrinsics.inl" 5e49a5e74f0b9ee68ccb1d0dc92ba8d330bb378946e46cb3c22a7d83755846b3 "${FX}/effect_symbol_table_intrinsics.inl")
fetch_file("${FX_URL}/effect_token.hpp" 2635a1f013eda6a49cb5e87a28a3dad1f0ee1870ef6645a59c4c69ecbb028666 "${FX}/effect_token.hpp")
set(SPIRV_URL "https://raw.githubusercontent.com/KhronosGroup/SPIRV-Headers/7845730cab6ebbdeb621e7349b7dc1a59c3377be/include/spirv/unified1")
fetch_file("${SPIRV_URL}/spirv.hpp" 43f4dcb231a8d61da50043f46e3aa04fa8b7c0ea53bb8b66c5ce70ac4ada51fe "${FX}/spirv/spirv.hpp")
fetch_file("${SPIRV_URL}/GLSL.std.450.h" 20f32378793c5f416bc0704f44345c2a14c99cba3f411e3beaf1bcea372d58ba "${FX}/spirv/GLSL.std.450.h")

# alloca lives in malloc.h on Windows and alloca.h on Linux.
file(READ "${FX}/effect_symbol_table.cpp" source)
string(REPLACE "#include <malloc.h> // alloca" "#include <alloca.h> // alloca" source "${source}")
file(WRITE "${FX}/patched/effect_symbol_table.cpp" "${source}")

add_executable(fxcheck fxcheck.cpp
    "${FX}/effect_codegen_hlsl.cpp" "${FX}/effect_codegen_spirv.cpp" "${FX}/effect_expression.cpp" "${FX}/effect_lexer.cpp"
    "${FX}/effect_parser_exp.cpp" "${FX}/effect_parser_stmt.cpp" "${FX}/effect_preprocessor.cpp"
    "${FX}/patched/effect_symbol_table.cpp")
target_include_directories(fxcheck PRIVATE "${FX}" "${FX}/spirv")
