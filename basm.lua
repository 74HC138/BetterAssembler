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

local recursionLimit = 15
local localIncludePath = {}


local TokenizeAssembly
local decodeArgument
local handleArguments
local isFolder
local isFile
local pathConcat
local findFile
local findFolder
local oFormatValid
local validateOptions
local loadAssembly
local assembler = {}


--creates a data table and returns it
assembler["formatData"] = function(data, format, size, lineLength, endian)
    local result = ""
    local buffer = ""
    local dataLength = #data
    local bufferCount = 0
    local function reverseTable(t)
        local reversedTable = {}
        local itemCount = #t
        for i = itemCount, 1, -1 do
            table.insert(reversedTable, t[i])
        end
        return reversedTable
    end
    local function addLine()
        result = result .. format .. " " .. buffer .. "\n"
        buffer = ""
    end
    local function getBytes(offset, count)
        local bytes = {}
        for i = 0, count - 1 do
            if offset + i > #data then
                table.insert(bytes, 0)
            else
                table.insert(bytes, string.byte(data, offset + i))
            end
        end
        if endian == "big" then
            return table.unpack(bytes)
        else
            return table.unpack(reverseTable(bytes))
        end
    end
    for i = 1, dataLength, size do
        local bytes = {getBytes(i, size)}
        local value = 0
        if endian == "little" then
            for j = 1, #bytes do
                value = value + (bytes[j] << ((j - 1) * 8))
            end
        else
            for j = 1, #bytes do
                value = value + (bytes[j] << ((#bytes - j) * 8))
            end
        end
        buffer = buffer .. string.format("0x%0" .. (size * 2) .. "X", value)
        bufferCount = bufferCount + 1
        if bufferCount >= lineLength or i + size - 1 >= dataLength then
            addLine()
            bufferCount = 0
        else
            buffer = buffer .. ", "
        end
    end
    if #buffer > 0 then
        addLine()
    end
    return result
end

local asmDirectives = {
    ["loadTime"] = {
        {{".include"}, 1, function(callingFile, recursion, args)
            local file = tostring(args[1])
            local path = findFile(file)
            assert(path, "could not find file \"" .. file .. "\"")
            assert(path ~= callingFile, "assembly file cant include itself!")
            assert(recursion < recursionLimit, "hit recursion limit! Maximum recursion depth is " .. recursionLimit)
            return loadAssembly(path, recursion)
        end},
        {{".includePath"}, 1, function(callingFile, recursion, args)
            local path = tostring(args[1])
            local fp = findFolder(path)
            assert(fp, "could not find direcory \"" .. path .. "\"")
            if #localIncludePath > 0 then
                table.insert(localIncludePath[#localIncludePath], fp)
            else
                error("Tried to add an include path to the localIncludePath but localIncludePath is not initialised. This should be impossible!", -1)
            end
            return nil
        end}

    }
}

TokenizeAssembly = function(input)
    local result = {}
    local depth = 0
    local buffer = ""
    local inString = false
    local specialChar = false

    input = tostring(input)

    for char in input:gmatch(".") do
        if string.gmatch(char, "%s")() ~= nil then
            --this is a whitespace
            if inString == false and specialChar == false then
                if #buffer > 0 and depth == 0 then
                    table.insert(result, buffer)
                    buffer = ""
                end
            else
                buffer = buffer .. char
            end
            specialChar = false
        elseif char == '(' then
            if specialChar == false and inString == false then
                depth = depth + 1
            end
            buffer = buffer .. char
            specialChar = false
        elseif char == ')' then
            if specialChar == false and inString == false then
                depth = depth - 1
                if depth < 0 then depth = 0 end
            end
            buffer = buffer .. char
            specialChar = false
        elseif char == ',' then
            if inString == false and specialChar == false then
                if depth == 0 then
                    table.insert(result, buffer)
                    buffer = ""
                else
                    buffer = buffer .. char
                end
            else
                buffer = buffer .. char
            end
            specialChar = false
        elseif char == ';' then
            --this starts a comment if not in a string
            if inString == false and specialChar == false then
                if #buffer > 0 then
                    table.insert(result, buffer)
                end
                return result
            else
                buffer = buffer .. char
                specialChar = false
            end
        elseif char == '\\' then
            --this starts a special character
            buffer = buffer .. char
            specialChar = true
        elseif char == '\"' then
            --this is a string delimitor
            if specialChar == false then
                inString = not inString
            end
            buffer = buffer .. char
            specialChar = false
        else
            buffer = buffer .. char
            specialChar = false
        end
    end
    if #buffer > 0 then
        table.insert(result, buffer)
    end
    return result
end

loadAssembly = function(file, recursion)

end


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
    {{"-I", "--include"}, 1, function(arg)
        local path = tostring(arg[1])
        if path.sub(1, 1) == '/' then
            table.insert(CompilerOptions["IncludePath"], path)
        else
            table.insert(CompilerOptions["IncludePath"], pathConcat("./", path))
        end
    end},
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
decodeArgument = function(arg)
    for _, command in pairs(argDefs) do
        for _, argument in pairs(command[1]) do
            if arg == argument then
                return command[2], command[3]
            end
        end
    end
    return 0, nil
end

handleArguments = function(arguments)
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
isFolder = function(path)
    local _, _, code = os.execute("test -d "..path)
    if code == 0 then
        return true
    else
        return false
    end
end
isFile = function(path)
    local _, _, code = os.execute("test -f "..path)
    if code == 0 then
        return true
    else
        return false
    end
end
pathConcat = function(path1, path2)
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
findFile = function(file)
    file = tostring(file)
    if file:sub(1, 1) == '/' then
        --this is an absolute path
        if isFile(file) then
            return file
        else
            return nil
        end
    end
    for _, path in pairs(CompilerOptions["IncludePath"]) do
        local fPath = pathConcat(path, file)
        if isFile(fPath) then
            return fPath
        end
    end
    if #localIncludePath > 0 then
        for _, path in pairs(localIncludePath[#localIncludePath]) do
            local fPath = pathConcat(path, file)
            if isFile(fPath) then
                return fPath
            end
        end
    end
    return nil
end
findFolder = function(path)
    path = tostring(path)
    if path:sub(1, 1) == '/' then
        if isFolder(path) then
            return path
        else
            return nil
        end
    end
    for _, p in pairs(CompilerOptions["IncludePath"]) do
        local fp = pathConcat(p, path)
        if isFolder(fp) then
            return fp
        end
    end
    if #localIncludePath > 0 then
        for _, p in pairs(localIncludePath[#localIncludePath]) do
            local fp = pathConcat(p, path)
            if isFolder(fp) then
                return fp
            end
        end
    end
    return nil
end
oFormatValid = function(fmt)
    if fmt == "bin" or fmt == "hex" then
        return true
    else
        return false
    end
end
validateOptions = function()
    assert(CompilerOptions["verbose"] >= 0 and CompilerOptions["verbose"] < 3, "Error: verbosity outside of defined range!")
    for _, path in pairs(CompilerOptions["IncludePath"]) do
        assert(isFolder(path), "\""..path.."\" is not a valid path!")
    end
    assert(CompilerOptions["Input"] == "", "Error: input file not defined!")
    assert(findFile(CompilerOptions["Input"]), "Error: could not find input file \""..CompilerOptions["Input"].."\"!")
    assert(oFormatValid(CompilerOptions["OFormat"]), "Error: unknown output format \""..CompilerOptions["OFormat"].."\"!")
    assert(isFile("./module/"..CompilerOptions["Arch"]..".lua"), "Error: unknown architecture \""..CompilerOptions["Arch"].."\"!")
end

--handleArguments(arg)
--validateOptions()



