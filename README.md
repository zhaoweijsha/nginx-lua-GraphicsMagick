# nginx-lua-GraphicsMagick
用Lua脚本实现的图片处理模块，目前实现了缩略图功能

## 说明
目前主要实现图片缩略图功能，可对不同目录配置缩略图尺寸。
主要将缩放的图片放在独立的thumb目录,并保持原有的图片目录结构.

#### 文件夹规划
```bash
img.xxx.com
|-- img1
|   `-- 001
|       `-- 001.jpg
|-- img2
|   `-- notfound.jpg
|-- img3
|   `-- 001
|       `-- 001.jpg
`-- thumb
    `-- img1
        `-- 001
            |-- 001_100x100.jpg
            |-- 001_200x160.jpg
```

其中img.xxx.com为图片站点根目录，img1,img2...目录是原图目录，可根据目录设置不同的缩略图尺寸，thumb文件夹用来存放缩略图，可定时清理。

#### 链接地址对应关系
* 原图访问地址：```http://img.xxx.com/xx/001/001.jpg```
* 缩略图访问地址：```http://img.xxx.com/xx/001/001.jpg_100x100.jpg``` (请勿加thumb)
* 实际缩略图地址：```http://img.xxx.com/thumb/xx/001/001.jpg_100x100.jpg``` (请勿加thumb)

#### 访问流程
* 首先判断缩略图是否存在，如存在则直接显示缩略图；
* 缩略图不存在,则判断原图是否存在，如原图存在则拼接graphicsmagick命令,生成并显示缩略图,否则返回404

## 配置


## 依赖
* Nginx(configure arguments: --prefix=/usr/local/nginx --user=www --group=www --pid-path=/opt/logs/nginx/nginx.pid --lock-path=/opt/logs/nginx/nginx.lock --error-log-path=/opt/logs/nginx/error.log --http-log-path=/opt/logs/nginx/access.log --with-http_ssl_module --with-http_realip_module --with-http_sub_module --with-http_flv_module --with-http_dav_module --with-http_gzip_static_module --with-http_stub_status_module --with-http_addition_module --with-zlib=../zlib-1.2.8 --with-pcre=../pcre-8.36 --add-module=../nginx-http-concat --add-module=../lua-nginx-module/ --add-module=../echo-nginx-module/ --add-module=../ngx_devel_kit/)
* GraphicsMagick(1.3.18)
  * libjpeg-6b
  * libpng-1.2.49
  * freetype-2.4.10    
* inotify(可选)

## 安装

#### nginx vhost 配置
server {
    listen   80;

    index index.php index.html index.htm;
    set $root_path '/var/www';
    root $root_path;


    location / {
            index  index.html index.htm;
    }


	location /lua {
		default_type 'text/plain';
      		content_by_lua 'ngx.say("hello, ttlsa lua")';
    }

    #/thumb目录下的图片请求不经过缩略图模块
    location ^~ /thumb/ {

    }

    # 所有符合规则的图片/xx/xx/xx.jpg_100x100.jpg
    location ~* ^(.+\.(jpg|jpeg|gif|png))_(\d+)+x(\d+)+\.(jpg|jpeg|gif|png)$ {
            root $root_path;    # 这里必须设置，否则根目录，即 $document_root 会是 Nginx 默认的 Nginx Root/html，在 Lua 中会得不到期望的值
            set $thumbnail_root $root_path/thumb;
            set $file $thumbnail_root$uri;             #如果缩略图文件存在，直接返回
            if (-f $file) {
                    rewrite ^/(.*)$ /thumb/$1 last;
            }

            if (!-f $file) {    # 如果文件不存在时才需要裁剪
                    add_header X-Powered-By 'Lua GraphicsMagick';    # 此 HTTP Header 无实际意义，用于测试
                    add_header file-path $request_filename;    # 此 HTTP Header 无实际意义，用于测试
                    set $request_filepath $root_path$1;    # 设置原始图片路径，如：/document_root/1.gif
                    set $img_width $3;    # 设置裁剪/缩放的宽度
                    set $img_height $4;    # 设置裁剪/缩放的高度
                    set $img_ext $5;    # 图片文件格式后缀
                    content_by_lua_file /etc/nginx/lua/img.lua;    # 加载外部 Lua 文件
            }
    }

    location ~ /\.ht {
        deny all;
    }
}

#### lua文件
-- 检测路径是否目录
local function is_dir(sPath)
    if type(sPath) ~= "string" then return false end

    local response = os.execute("cd " .. sPath)
    if response == 0 then
        return true
    end
    return false
end

-- 文件是否存在
function file_exists(name)
    local f = io.open(name, "r")
    if f ~= nil then io.close(f) return true else return false end
end

-- 获取文件路径
function getFileDir(filename)
    return string.match(filename, "(.+)/[^/]*%.%w+$") --*nix system
end

-- 获取文件名
function strippath(filename)
    return string.match(filename, ".+/([^/]*%.%w+)$") -- *nix system
end

--去除扩展名
function stripextension(filename)
    local idx = filename:match(".+()%.%w+$")
    if (idx) then
        return filename:sub(1, idx - 1)
    else
        return filename
    end
end

--获取扩展名
function getExtension(filename)
    return filename:match(".+%.(%w+)$")
end

-- 开始执行
-- ngx.log(ngx.ERR, getFileDir(ngx.var.file));

local gm_path = '/usr/local/bin/gm'

-- check image dir
if not is_dir(getFileDir(ngx.var.file)) then
    os.execute("mkdir -p " .. getFileDir(ngx.var.file))
end

-- 如果原始文件存在,则缩放(以最小边,不变形)
if (file_exists(ngx.var.request_filepath)) then
    local cmd = gm_path .. ' convert ' .. ngx.var.request_filepath
    cmd = cmd .. " -resize " .. ngx.var.img_width .. "x" .. ngx.var.img_height
    cmd = cmd .. " +profile \"*\" " .. ngx.var.file;
    ngx.log(ngx.ERR, cmd);
    os.execute(cmd);
    ngx.exec(ngx.var.uri);
else
    ngx.exit(ngx.HTTP_NOT_FOUND);
end

