// Compiles a ReShade effect the way ReShade does, for one code generator, and writes the code of each entry point
// to <out>.<entry point> so another compiler can check it too.
// Usage: fxcheck <effect.fx> <hlsl|spirv> <out>
#include "effect_codegen.hpp"
#include "effect_parser.hpp"
#include "effect_preprocessor.hpp"
#include <cstdio>
#include <fstream>
#include <memory>
#include <string>

int main(int argc, char* argv[])
{
    if (argc != 4)
    {
        std::fprintf(stderr, "usage: fxcheck <effect.fx> <hlsl|spirv> <out>\n");
        return 2;
    }
    const std::string kind = argv[2];

    // The macros ReShade defines, with a 1920x1080 SDR screen on Direct3D 11 (which Unishade uses).
    reshadefx::preprocessor pp;
    pp.add_macro_definition("__RESHADE__", "60800");
    pp.add_macro_definition("__RENDERER__", "0xb000");
    pp.add_macro_definition("BUFFER_WIDTH", "1920");
    pp.add_macro_definition("BUFFER_HEIGHT", "1080");
    pp.add_macro_definition("BUFFER_RCP_WIDTH", "(1.0 / BUFFER_WIDTH)");
    pp.add_macro_definition("BUFFER_RCP_HEIGHT", "(1.0 / BUFFER_HEIGHT)");
    pp.add_macro_definition("BUFFER_COLOR_BIT_DEPTH", "8");
    pp.add_macro_definition("BUFFER_COLOR_SPACE", "1");
    const bool preprocessed = pp.append_file(argv[1]);
    std::fputs(pp.errors().c_str(), stderr);
    if (!preprocessed)
        return 1;

    std::unique_ptr<reshadefx::codegen> codegen(kind == "spirv" ? reshadefx::create_codegen_spirv(true, false, false)
                                                                : reshadefx::create_codegen_hlsl(50, false, false));
    reshadefx::parser parser;
    const bool parsed = parser.parse(pp.output(), codegen.get());
    std::fputs(parser.errors().c_str(), stderr);
    if (!parsed)
        return 1;

    const reshadefx::effect_module& module = codegen->module();
    for (const auto& technique : module.techniques)
        std::printf("technique %s: %zu passes\n", technique.name.c_str(), technique.passes.size());
    for (const auto& entry : module.entry_points)
    {
        std::string code, assembly, errors;
        if (!codegen->assemble_code_for_entry_point(entry.first, code, assembly, errors))
        {
            std::fprintf(stderr, "%s: %s\n", entry.first.c_str(), errors.c_str());
            return 1;
        }
        std::ofstream(std::string(argv[3]) + "." + entry.first, std::ios::binary) << code;
        std::printf("entry point %s\n", entry.first.c_str());
    }
    return 0;
}
