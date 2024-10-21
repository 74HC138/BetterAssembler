--module for the motorola 68000

local fnTable = {}

--initialisation function for module
fnTable["init"] = function()

end

--decode instruction to byte array
fnTable["decode"] = function(str)

end

--decode instruction to length of instruction
fnTable["preDecode"] = function(str)

end

--if possible optimise instruction
fnTable["optimise"] = function(str, level)

end

return fnTable