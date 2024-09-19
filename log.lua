local Log = {}

-- 定义日志缓存和写入阈值
Log.cache = {}
Log.flushLimit = 100 -- 每100条日志写入一次
Log.filepath = "nuclear_log.txt"
Log.maxFileSize = 1024 * 1024 -- 1MB

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

function Log:append(message)
    -- 确保 cache 被初始化
    if type(self.cache) ~= "table" then
        self.cache = {}
    end

    -- 调试信息
    print("Debug: cache = ", self.cache, " type = ", type(self.cache))
    print("Debug: cache length = ", #self.cache)
    
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local logEntry = tostring(timestamp) .. " - " .. tostring(message)
    print("Debug: logEntry = ", logEntry, " type = ", type(logEntry))
    
    table.insert(self.cache, logEntry)
    
    -- 当缓存的日志数量超过 flushLimit 时，写入文件
    if #self.cache >= self.flushLimit then
        self:flush()
    end
end

-- 将缓存中的日志写入文件
function Log:flush()
    self:rotate() -- 检查并轮换日志文件
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
    local file, err = io.open("test_log.txt", "w")
    if not file then
        print("Error creating test file: " .. (err or "unknown error"))
    else
        file:write("Test log entry\n")
        file:close()
        print("Test file created successfully")
    end
end

testFileCreation()

return Log
