#!/bin/lua

CompilerOptions = {
    ["verbose"] = 0,
    ["IncludePath"] = {
        "./",
    },
    ["Input"] = "",
    ["Output"] = "out.bin",
    ["OFormat"] = "bin",
    ["Listing"] = "",
    ["Arch"] = "",
}




--[[
possible arguments:
    -v --verbose        [none]: enable verbose output
    -V --VERBOSE        [none]: enable super verbose output
    -I --include        [path]: add additional include path
    -h --help           [none]: display help
    -i --input          [file]: set input file
    -o --output         [file]: set output file
    -F --outputFormat   [type]: set the output format
    -l --list           [file]: enable output listing
    -a --arch           [arch]: set architecture
--]]
local argDefs = {
    {{"-v", "--verbose"}, 0, function(arg) CompilerOptions["verbose"] = 1 end},
    {{"-V", "--VERBOSE"}, 0, function(arg) CompilerOptions["verbose"] = 2 end},
    {{"-I", "--include"}, 1, function(arg) table.insert(CompilerOptions["IncludePath"], arg[1]) end},
    {{"-h", "--help"}, 0, function(arg)
        print("[TODO] display help")
        os.exit(0)
    end},
    {{"-i", "--input"}, 1, function(arg) CompilerOptions["Input"] = arg[1] end},
    {{"-o", "--output"}, 1, function(arg) CompilerOptions["Output"] = arg[1] end},
    {{"-F", "--outputFormat"}, 1, function(arg) CompilerOptions["OFormat"] = arg[1] end},
    {{"-l", "--list"}, 1, function(arg) CompilerOptions["Listing"] = arg[1] end},
    {{"-a", "--arch"}, 1, function(arg) CompilerOptions["Arch"] = arg[1] end},
}
local function decodeArgument(arg)
    for _, command in pairs(argDefs) do
        for _, argument in pairs(command[1]) do
            if arg == argument then
                return command[2], command[3]
            end
        end
    end
    return 0, nil
end
local function handleArguments(arguments)
    local callback = nil
    local nParameters = 0
    local parameters = {}
    for index, val in ipairs(arguments) do
        if nParameters > 0 then
            table.insert(parameters, val)
            nParameters = nParameters - 1
            if nParameters == 0 and callback ~= nil then
                callback(parameters)
                parameters = {}
            end
        else
            nParameters, callback = decodeArgument(val)
            if nParameters == 0 then
                if callback ~= nil then
                    callback()
                else
                    --not a command!!
                    print("\"" .. tostring(val) .. "\" is not a command. Use -h to list all commands\n")
                    os.exit(1)
                end
            end
        end
    end
end
local function isFolder(path)
    local _, _, code = os.execute("test -d "..path)
    if code == 0 then
        return true
    else
        return false
    end
end
local function isFile(path)
    local _, _, code = os.execute("test -f "..path)
    if code == 0 then
        return true
    else
        return false
    end
end
local function pathConcat(path1, path2)
    path1 = tostring(path1)
    path2 = tostring(path2)

    if path1:sub(-1) == "/" then
        path1 = path1:sub(1, -2)
    end
    if path2:sub(1, 1) == "/" then
        path2 = path2.sub(2, -1)
    end
    return path1 .. "/" .. path2
end
local function findFile(file)
    for _, path in pairs(CompilerOptions["IncludePath"]) do
        local fPath = pathConcat(path, file)
        if isFile(fPath) then
            return fPath
        end
    end
    return nil
end
local function oFormatValid(fmt)
    if fmt == "bin" or fmt == "hex" then
        return true
    else
        return false
    end
end
local function validateOptions()
    assert(CompilerOptions["verbose"] >= 0 and CompilerOptions["verbose"] < 3, "Error: verbosity outside of defined range!")
    for _, path in pairs(CompilerOptions["IncludePath"]) do
        assert(isFolder(path), "\""..path.."\" is not a valid path!")
    end
    assert(CompilerOptions["Input"] == "", "Error: input file not defined!")
    assert(findFile(CompilerOptions["Input"]), "Error: could not find input file \""..CompilerOptions["Input"].."\"!")
    assert(oFormatValid(CompilerOptions["OFormat"]), "Error: unknown output format \""..CompilerOptions["OFormat"].."\"!")
    assert(isFile("./module/"..CompilerOptions["Arch"]..".lua"), "Error: unknown architecture \""..CompilerOptions["Arch"].."\"!")
end

handleArguments(arg)
validateOptions()
