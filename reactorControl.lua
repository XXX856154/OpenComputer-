local Log = {}

-- 定义日志缓存和写入阈值
Log.cache = {}
Log.flushLimit = 100 -- 每100条日志写入一次
Log.filepath = "./nuclear_log.txt"
Log.maxFileSize = 1024 * 1024 -- 1MB
Log.maxLines = 1000 -- 最大日志行数

-- 检查并轮换日志文件
function Log:rotate()
    local file = io.open(self.filepath, "r")
    if file then
        local size = file:seek("end")
        file:close()
        if size > self.maxFileSize then
            os.rename(self.filepath, self.filepath .. os.date("_%Y%m%d%H%M%S"))
        end
    end
end

-- 删除并重新生成日志文件
function Log:resetLogFile()
    local file = io.open(self.filepath, "r")
    if file then
        file:close()
        os.remove(self.filepath)
    end
    local newFile, err = io.open(self.filepath, "w")
    if not newFile then
        print("Error creating new log file: " .. (err or "unknown error"))
    else
        newFile:close()
    end
end

-- 检查日志文件行数
function Log:checkLineCount()
    local file = io.open(self.filepath, "r")
    if not file then return 0 end
    local count = 0
    for _ in file:lines() do
        count = count + 1
    end
    file:close()
    return count
end

function Log:append(message)
    -- 确保 cache 被初始化
    if type(self.cache) ~= "table" then
        self.cache = {}
    end

    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local logEntry = tostring(timestamp) .. " - " .. tostring(message)
    table.insert(self.cache, logEntry)
    
    -- 当缓存的日志数量超过 flushLimit 时，写入文件
    if #self.cache >= self.flushLimit then
        self:flush()
    end
end

-- 将缓存中的日志写入文件
function Log:flush()
    self:rotate() -- 检查并轮换日志文件
    local lineCount = self:checkLineCount()
    if lineCount >= self.maxLines then
        self:resetLogFile()
    end
    local file, err = io.open(self.filepath, "a")
    if not file then
        print("Error opening file for appending: " .. (err or "unknown error"))
        return
    end
    for _, log in ipairs(self.cache) do
        file:write(log .. "\n")
    end
    file:close()
    -- 清空缓存
    self.cache = {}
end

-- 测试文件创建
local function testFileCreation()
    local file, err = io.open("/mnt/0f2/test_log.txt", "w")
    if not file then
        print("Error creating test file: " .. (err or "unknown error"))
    else
        file:write("Test log entry\n")
        file:close()
        print("Test file created successfully")
    end
end

-- 重置日志文件
Log:resetLogFile()

return Log
