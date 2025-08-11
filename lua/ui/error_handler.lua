local M = {}

local progress = require("ui.progress")

-- Connection status tracking
 M.connection_status = {
   last_successful_request = nil,
   consecutive_failures = 0,
   is_server_down = false,
 }

 -- Check if llama-server is running
 function M.check_server_status()
   local config = require("flux").config
   local url = string.format("http://%s:%d/health", config.host, config.port)
   local curl_cmd = string.format("curl -s --max-time 5 %s || echo 'FAILED'", url)

   local handle = vim.fn.jobstart(curl_cmd, {
     on_stdout = function(_, data)
       if data and #data > 0 then
         local response = table.concat(data, "")
         if response:match("FAILED") then
           M.connection_status.is_server_down = true
         else
           M.connection_status.is_server_down = false
           M.connection_status.consecutive_failures = 0
           M.connection_status.last_successful_request = os.time()
         end
       end
     end,
     on_stderr = function(_, data)
       M.connection_status.is_server_down = true
     end,
     on_exit = function(_, exit_code)
       if exit_code ~= 0 then
         M.connection_status.is_server_down = true
       end
     end
   })
   return handle
 end

 -- Get user-friendly error message
 function M.get_error_message(error_type, details)
   local config = require("flux").config
   local messages = {
     connection_failed = string.format("🔌 Cannot connect to llama-server on %s:%d", config.host, config.port),
     timeout = "⏰ Request timed out - llama-server may be overloaded" ,
     invalid_response = "📄 Received invalid response from llama-server",
     server_error = "🚨 llama-server returned an error",
     max_retries_exceeded = "🔄 Maximum retries exceeded - please check your setup",
   }

   local base_message = messages[error_type] or "❌ Unknown error occurred"

   if details then
     return base_message .. "\n\nDetails: " .. details
   end

   return base_message
 end

 -- Show error notification with action suggestions
 function M.show_error_notification(error_type, details, suggestions)
   local message = M.get_error_message(error_type, details)

   if suggestions then
     message = message .. "\n\n💡 Suggestions:\n" .. table.concat(suggestions, "\n")
   end

   vim.notify(message, vim.log.levels.ERROR)
 end

 -- Get error suggestions based on error type
 function M.get_error_suggestions(error_type)
   local suggestions = {
     connection_failed = {
       "• Start llama-server: llama-server -m model.gguf --port 1234",
       "• Check if port 1234 is in use: lsof -i :1234",
       "• Verify llama-server is running: curl http://localhost:1234/health"
     },
     timeout = {
       "• Try a smaller model if available",
       "• Reduce max_tokens in the request",
       "• Wait for current operations to complete"
     },
     invalid_response = {
       "• Check llama-server logs for errors",
       "• Restart llama-server",
       "• Verify model is compatible"
     },
     server_error = {
       "• Check llama-server logs: tail -f server.log",
       "• • Restart llama-server with --verbose flag",
       "• Try a different model"
     }
   }

   return suggestions[error_type] or {"• Check llama-server status and logs"}
 end

 -- Connection status indicator
 function M.get_connection_status_indicator()
   if M.connection_status.is_server_down then
     return "🔴 Server Down"
   elseif M.connection_status.consecutive_failures > 0 then
     return "🟡 Connection Issues (" .. M.connection_status.consecutive_failures .. ")"
   elseif M.connection_status.last_successful_request then
     local time_since = os.time() - M.connection_status.last_successful_request
     if time_since < 30 then
       return "🟢 Connected"
     elseif time_since < 300 then -- 5 minutes
       return "🟡 Idle (" .. time_since .. "s)"
     else
       return "⚪ Unknown Status"
     end
   else
     return "⚪ Not Connected"
   end
 end

 -- Setup periodic health checks
 function M.setup_health_monitoring()
   -- Check server health every 30 seconds
   local timer = vim.fn.timer_start(30000, function()
     M.check_server_status()
   end, { ['repeat'] = -1 })

   return timer
 end

 -- Manual server status check command
 function M.manual_status_check()
   local handle = progress.start("check", "Checking server status...")

   M.check_server_status()

   vim.defer_fn(function()
     local status = M.get_connection_status_indicator()
     progress.complete(handle, "Status: " .. status)
     vim.notify("llama-server status: " .. status, vim.log.levels.INFO)
   end, 2000)
 end

 return M
