cmake_minimum_required(VERSION 3.20)
project(CinematicShots VERSION 0.1.0 LANGUAGES CXX)

if(NOT WIN32 OR NOT CMAKE_SIZEOF_VOID_P EQUAL 8)
    message(FATAL_ERROR "Build on Windows for x64: cmake -S . -B build -A x64")
endif()

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
# Static CRT, so the add-on needs no Visual C++ runtime installed. Unishade builds the same way.
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

# Downloads a file once and checks its SHA-256.
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

# ReShade add-on API headers, pinned to the same tag Unishade builds against (v6.8.0, RESHADE_API_VERSION 20).
set(RESHADE_INCLUDE "${CMAKE_BINARY_DIR}/reshade/include")
set(RESHADE_HEADERS_URL "https://raw.githubusercontent.com/crosire/reshade/v6.8.0/include")
fetch_file("${RESHADE_HEADERS_URL}/reshade.hpp" cf3cd150920ea310b4b1e2e4f11ab8d7221a9fc18755f4891a026563311b524c "${RESHADE_INCLUDE}/reshade.hpp")
fetch_file("${RESHADE_HEADERS_URL}/reshade_api.hpp" 8d83ec8a620c48da7a20d975bd27b3345b24d3f0d5b78ae4c4fe633d61b804eb "${RESHADE_INCLUDE}/reshade_api.hpp")
fetch_file("${RESHADE_HEADERS_URL}/reshade_api_device.hpp" a716c44b6fbb064dbbb0826687728f21aa71ed45e13564e4dc1cdf36da5bdfa0 "${RESHADE_INCLUDE}/reshade_api_device.hpp")
fetch_file("${RESHADE_HEADERS_URL}/reshade_api_format.hpp" 68caa17fef712043e810ab88770c15af009aa3c7693e5c115ddc324f2d0809a7 "${RESHADE_INCLUDE}/reshade_api_format.hpp")
fetch_file("${RESHADE_HEADERS_URL}/reshade_api_pipeline.hpp" 5bda8e07260c2c60f0fd18a78b11782aed8f69e5d24b5757874614caafdf416f "${RESHADE_INCLUDE}/reshade_api_pipeline.hpp")
fetch_file("${RESHADE_HEADERS_URL}/reshade_api_resource.hpp" 32cdafe6d783813f3ac72ad43e426638d8d0fef56bcb558fad218a14cfb75ee3 "${RESHADE_INCLUDE}/reshade_api_resource.hpp")
fetch_file("${RESHADE_HEADERS_URL}/reshade_events.hpp" 2717f56e2bd89af6d708c9c316353d6581c5a41d4526629fadba51d13be57a89 "${RESHADE_INCLUDE}/reshade_events.hpp")
fetch_file("${RESHADE_HEADERS_URL}/reshade_overlay.hpp" ed914b12fbc41ed038287b0163c0bc934772afcff2c22392044c6008adc5ae79 "${RESHADE_INCLUDE}/reshade_overlay.hpp")

# Only the Dear ImGui header: the functions themselves are ReShade's, reached through its function table.
# reshade_overlay.hpp at v6.8.0 requires IMGUI_VERSION_NUM 19250, which is 1.92.5 (docking branch, like ReShade).
set(IMGUI_INCLUDE "${CMAKE_BINARY_DIR}/imgui")
fetch_file("https://raw.githubusercontent.com/ocornut/imgui/v1.92.5-docking/imgui.h" 07562842049eaca4e47c3fcdcc9d8eafd442695b9856d6f6639e92e1bb6c737e "${IMGUI_INCLUDE}/imgui.h")
fetch_file("https://raw.githubusercontent.com/ocornut/imgui/v1.92.5-docking/imconfig.h" 6e5687893594ebfaf8569280cfea83d025904a8a4e23bec073086f6c5bc8f7fb "${IMGUI_INCLUDE}/imconfig.h")

add_library(CinematicShots SHARED src/addon.cpp)
target_include_directories(CinematicShots PRIVATE "${RESHADE_INCLUDE}" "${IMGUI_INCLUDE}")
target_compile_definitions(CinematicShots PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX)
target_compile_options(CinematicShots PRIVATE /W4 /utf-8)
# ReShade loads add-ons by their .addon64 extension.
set_target_properties(CinematicShots PROPERTIES PREFIX "" SUFFIX ".addon64")
