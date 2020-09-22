--- Includes
local http_server  = require 'http.server'
local http_headers = require 'http.headers'
local sha1         = require 'sha1'

--- Configuration
local port = 80

local git_from = 'https://github.com/user/source_repo'
local git_to   = 'https://github.com/user/destination_repo'

local secret = 'my_secret_hehe'

local mirror_folder = 'mirror_repo'

--- File Helpers
local function file_exists(file)
  return os.rename(file, file)
end

local function dir_exists(path)
  return file_exists(path.. '/')
end

local function make_dir(path)
  return os.execute('mkdir '..path)
end

--- Git Helpers
local function git_execute(command)
  command = 'git -C '..mirror_folder..' '..command
  io.stdout:write('Executing: '..command..'\n')
  os.execute(command)
end

local function setup_repo()
  make_dir(mirror_folder)
  git_execute('init')
  git_execute('remote add upstream '..git_from)
  git_execute('remote add mirror '..git_to)
end

local function fetch_repo()
  git_execute('fetch upstream')
  git_execute('reset upstream/master')
end

local function push_repo()
  git_execute('push --force mirror master')
end

local function mirror_repo()
  if not dir_exists(mirror_folder) then
    setup_repo()
  end

  fetch_repo()
  push_repo()
end

--- Server Implementation
local function reply(server, stream)
  local req_headers = stream:get_headers()
  local req_method  = req_headers:get(':method')

  local event     = req_headers:get('X-GitHub-Event')
  local gihub_sig = req_headers:get('X-Hub-Signature')

  local content   = stream:get_body_as_string()
  local signature = sha1.hmac(secret, content)

  local res_headers = http_headers.new()
  res_headers:append(':status', '200')
  res_headers:append('content-type', 'text/plain')
  stream:write_headers(res_headers, req_method == "HEAD")

  if req_method == 'HEAD' then
    return
  elseif req_method ~= 'POST' then
    stream:write_chunk('I am simply just vibing.\n', true)
    return
  end

  if event ~= 'push' then
    io.stdout.write('Invalid event recieved', '\n')
    return
  end

  if github_sig ~= signature then
    io.stdout.write('Invalid signature recieved', '\n')
    return
  end
  
  mirror_repo()

  stream:write_chunk('Updated mirror.\n', true)
end

local server = http_server.listen {
  host     = '0.0.0.0',
  port     = port,
  onstream = reply,
  onerror  = function(server, context, op, err, errno)
    local msg = op..' on '..tostring(context)..' failed'
    if err then
      msg = msg..': '..tostring(err)
    end
    io.stderr:write(msg, '\n')
  end
}

server:listen()
do
  local bound_port = select(3, server:localname())
  io.stderr:write(string.format('Now listening on port %d\n', bound_port))
end
server:loop()
