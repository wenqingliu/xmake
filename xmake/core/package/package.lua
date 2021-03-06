--!A cross-platform build utility based on Lua
--
-- Licensed to the Apache Software Foundation (ASF) under one
-- or more contributor license agreements.  See the NOTICE file
-- distributed with this work for additional information
-- regarding copyright ownership.  The ASF licenses this file
-- to you under the Apache License, Version 2.0 (the
-- "License"); you may not use this file except in compliance
-- with the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific package governing permissions and
-- limitations under the License.
-- 
-- Copyright (C) 2015 - 2017, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        package.lua
--

-- define module
local package   = package or {}
local _instance = _instance or {}

-- load modules
local os          = require("base/os")
local io          = require("base/io")
local path        = require("base/path")
local utils       = require("base/utils")
local table       = require("base/table")
local filter      = require("base/filter")
local global      = require("base/global")
local interpreter = require("base/interpreter")
local sandbox     = require("sandbox/sandbox")
local config      = require("project/config")
local project     = require("project/project")
local platform    = require("platform/platform")
local import      = require("sandbox/modules/import")

-- new an instance
function _instance.new(name, info, rootdir)

    -- new an instance
    local instance = table.inherit(_instance)

    -- parse name .e.g vendor.name
    local nameinfo = name:split("%.")

    -- init instance
    instance._FULLNAME  = name
    instance._NAME      = nameinfo[2] or name
    instance._VENDOR    = nameinfo[1]
    instance._INFO      = info
    instance._ROOTDIR   = rootdir
    instance._FILTER    = filter.new()

    -- register filter handler
    instance._FILTER:register("package", function (variable)

        -- init maps
        local maps = 
        {
            version = instance:version_str()
        }

        -- map it
        return maps[variable]
    end)

    -- ok
    return instance
end

-- get the package configure
function _instance:get(name)

    -- the info
    local info = self._INFO

    -- get if from info first
    local value = info[name]
    if value ~= nil then
        return value 
    end
end

-- get the package full name with vendor
function _instance:fullname()
    return self._FULLNAME
end

-- get the package name without vendor
function _instance:name()
    return self._NAME
end

-- get the package vendor 
function _instance:vendor()
    return self._VENDOR
end

-- get the package filter 
function _instance:filter()
    return self._FILTER
end

-- get urls
function _instance:urls()
    return self._URLS or table.wrap(self:get("urls"))
end

-- get urls
function _instance:urls_set(urls)
    self._URLS = urls
end

-- get deps
function _instance:deps()
    return self._DEPS
end

-- get order deps
function _instance:orderdeps()
    return self._ORDERDEPS
end

-- get sha256
function _instance:sha256()

    -- get it from cache first
    if self._SHA256 then
        return self._SHA256
    end

    -- find sha256
    local version  = self:version()
    local sha256s  = table.wrap(self:get("sha256s"))
    local versions = table.wrap(self:get("versions"))
    if version then
        for idx, ver in ipairs(versions) do
            if ver == version then
                self._SHA256 = sha256s[idx]
                break
            end
        end
    end

    -- get it
    return self._SHA256
end

-- this package is from system/local/global?
--
-- @param kind  the from kind
--
-- system: from the system directories (.e.g /usr/local)
-- local:  from the local project package directories (.e.g projectdir/.xmake/packages)
-- global: from the global package directories (.e.g ~/.xmake/packages)
--
function _instance:from(kind)
    return self._FROMKIND == kind
end

-- get the cached directory of this package
function _instance:cachedir()
    return path.join(package.cachedir(), self:fullname(), self:version_str())
end

-- get the installed directory of this package
function _instance:installdir()

    -- only be a system package without urls, no installdir
    if self:from("system") then
        return 
    end

    -- make install directory
    return path.join(package.installdir(self:from("global")), self:fullname(), self:version_str())
end

-- get the version  
function _instance:version()
    return self._VERSION or {}
end

-- get the version string 
function _instance:version_str()
    return self:version().raw or self:version().version
end

-- the verson from tags, branches or versions?
function _instance:version_from(...)

    -- from source?
    for _, source in ipairs({...}) do
        return self:version().source == source
    end
end

-- set the version
function _instance:version_set(version, source)

    -- init package version
    if type(version) == "string" then
        version = {version = version, source = source}
    else
        version.source = source
    end

    -- save version
    self._VERSION = version
end

-- get the require info 
function _instance:requireinfo()
    return self._REQUIREINFO 
end

-- set the require info 
function _instance:requireinfo_set(requireinfo)
    self._REQUIREINFO = requireinfo
end

-- get xxx_script
function _instance:script(name, generic)

    -- get script
    local script = self:get(name)
    if type(script) == "function" then
        return script
    elseif type(script) == "table" then

        -- match script for special plat and arch
        local plat = (config.get("plat") or "")
        local pattern = plat .. '|' .. (config.get("arch") or "")
        for _pattern, _script in pairs(script) do
            if not _pattern:startswith("__") and pattern:find('^' .. _pattern .. '$') then
                return _script
            end
        end

        -- match script for special plat
        for _pattern, _script in pairs(script) do
            if not _pattern:startswith("__") and plat:find('^' .. _pattern .. '$') then
                return _script
            end
        end

        -- get generic script
        return script["__generic__"] or generic
    end

    -- only generic script
    return generic
end

-- fetch package info from the local packages
--
-- @return {packageinfo}, fetchfrom (.e.g local/global/system)
--
function _instance:fetch()

    -- import find_package
    self._find_package = self._find_package or import("lib.detect.find_package", {anonymous = true})

    -- fetch it from the package directories first
    local fetchfrom  = self._FETCHFROM
    local fetchinfo  = self._FETCHINFO
    local installdir = self:installdir()
    if not fetchinfo and installdir then
        fetchinfo = self._find_package(self:name(), {packagedirs = installdir, system = false, force = true}) -- disable cache and system packages
        if fetchinfo then fetchfrom = self._FROMKIND end
    end

    -- fetch it from the system directories
    if not fetchinfo then
        local system = self:requireinfo().system
        if system == nil then -- find system package by default
            system = true
        end
        if system then
            fetchinfo = self._find_package(self:name())
            if fetchinfo then fetchfrom = "system" end
        end
    end

    -- save to cache
    self._FETCHINFO = fetchinfo
    self._FETCHFROM = fetchfrom

    -- ok
    return fetchinfo, fetchfrom
end

-- exists this package in local
function _instance:exists()
    return self._FETCHINFO
end

-- the interpreter
function package._interpreter()

    -- the interpreter has been initialized? return it directly
    if package._INTERPRETER then
        return package._INTERPRETER
    end

    -- init interpreter
    local interp = interpreter.new()
    assert(interp)
 
    -- define apis
    interp:api_define(package.apis())
    
    -- save interpreter
    package._INTERPRETER = interp

    -- ok?
    return interp
end

-- get package apis
function package.apis()

    return 
    {
        values =
        {
            -- package.set_xxx
            "package.set_urls"
        ,   "package.set_sha256s"
        ,   "package.set_versions"
        ,   "package.set_homepage"
        ,   "package.set_description"
            -- package.add_xxx
        ,   "package.add_deps"
        }
    ,   script =
        {
            -- package.on_xxx
            "package.on_build"
        ,   "package.on_install"
        ,   "package.on_test"

            -- package.before_xxx
        ,   "package.before_build"
        ,   "package.before_install"
        ,   "package.before_test"

            -- package.before_xxx
        ,   "package.after_build"
        ,   "package.after_install"
        ,   "package.after_test"
        }
    }
end

-- get install directory
function package.installdir(is_global)

    -- get directory
    if is_global then
        return path.join(global.directory(), "packages")
    else
        return path.join(config.directory(), "packages")
    end
end

-- the cache directory
function package.cachedir()
    return path.join(global.directory(), "cache", "packages")
end

-- load the package from the package url
function package.load_from_url(packagename, packageurl)

    -- make a temporary package file
    local packagefile = os.tmpfile() .. ".lua"

    -- make package description
    local packagedata = string.format([[
    package("%s")
        set_urls("%s")
    ]], packagename, packageurl)

    -- write a temporary package description to file
    local ok, errors = io.writefile(packagefile, packagedata)
    if not ok then
        return nil, errors
    end

    -- load package instance
    local instance, errors = package.load_from_repository(packagename, false, nil, packagefile)

    -- remove the package file
    os.rm(packagefile)

    -- ok?
    return instance, errors
end

-- load the package from the system directories
function package.load_from_system(packagename)

    -- get it directly from cache first
    package._PACKAGES = package._PACKAGES or {}
    if package._PACKAGES[packagename] then
        return package._PACKAGES[packagename]
    end

    -- new an empty instance
    local instance, errors = _instance.new(packagename, {}, package._interpreter():rootdir())
    if not instance then
        return nil, errors
    end

    -- mark as system package
    instance._FROMKIND = "system"

    -- save instance to the cache
    package._PACKAGES[packagename] = instance

    -- ok
    return instance
end

-- load the package from the project file
function package.load_from_project(packagename)

    -- get it directly from cache first
    package._PACKAGES = package._PACKAGES or {}
    if package._PACKAGES[packagename] then
        return package._PACKAGES[packagename]
    end

    -- load packages (with cache)
    local packages, errors = project.packages()
    if not packages then
        return nil, errors
    end

    -- get interpreter
    local interp = errors or package._interpreter()

    -- not found?
    if not packages[packagename] then
        return
    end

    -- new an instance
    local instance, errors = _instance.new(packagename, packages[packagename], interp:rootdir())
    if not instance then
        return nil, errors
    end

    -- mark as local package
    instance._FROMKIND = "local"

    -- save instance to the cache
    package._PACKAGES[packagename] = instance

    -- ok
    return instance
end

-- load the package from the package directory or package description file
function package.load_from_repository(packagename, is_global, packagedir, packagefile)

    -- get it directly from cache first
    package._PACKAGES = package._PACKAGES or {}
    if package._PACKAGES[packagename] then
        return package._PACKAGES[packagename]
    end

    -- find the package script path
    local scriptpath = packagefile
    if not packagefile and packagedir then
        scriptpath = path.join(packagedir, "xmake.lua")
    end
    if not scriptpath or not os.isfile(scriptpath) then
        return nil, string.format("the package %s not found!", packagename)
    end

    -- load package and disable filter, we will process filter after a while
    local results, errors = package._interpreter():load(scriptpath, "package", true, false)
    if not results and os.isfile(scriptpath) then
        return nil, errors
    end

    -- check the package name
    if not results[packagename] then
        return nil, string.format("the package %s not found!", name)
    end

    -- new an instance
    local instance, errors = _instance.new(packagename, results[packagename], package._interpreter():rootdir())
    if not instance then
        return nil, errors
    end

    -- mark as global/project package?
    instance._FROMKIND = utils.ifelse(is_global, "global", "local")

    -- save instance to the cache
    package._PACKAGES[packagename] = instance

    -- ok
    return instance
end
     
-- return module
return package
