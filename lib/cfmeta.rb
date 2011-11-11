require "cfmeta/version"
require 'json/pure'
require 'zip/zipfilesystem'
require 'tmpdir'
require 'open-uri'
require 'vmc'

module Cfmeta
  extend self
  class Cfmeta
    PACK_EXCLUSION_GLOBS = ['..', '.', '*~', '#*#', '*.log']

    apptmp = JSON.parse(ENV['VCAP_APPLICATION'])
    $appname = apptmp['name']
    $appuser = apptmp['users'][0]

    def initialize (password,target="api.cloudfoundry.com")
      @vmcclient = VMC::Client.new(target)
      @vmcclient.login($appuser, password)
      $target = target
      $serviceinventory = JSON.parse(ENV['VCAP_SERVICES'])
      $unboundinventory = @vmcclient.services
      $appinventory = @vmcclient.apps
    end

    def bound(service,name=$appname)
      @service = service
      app_name = name
      $appinventory.each do |item|
        if item[:name] == app_name then
          if item[:services] != nil then
            return true
          end
        end
      end
    end
    
    def services(name=$appname)
      @app_name = $appname
      $appinventory.each do |item|
        if item[:name] == @app_name then
          return item[:services]
        end
      end
    end

    def exists(service)
      @service = service
      $unboundinventory.each do |uinventory| 
        if uinventory.value?(@service) == true then
          return true
        end
      end
    end

    def bind(service,name=$appname)
      @service = service
      @app_name = name
      begin
        @vmcclient.bind_service(@service, @app_name)
      rescue
        puts "Service Failed to Bind"
      end
    end
  
    def unbind(service,name=$appname)
      @service = service
      @app_name = name
      begin
        @vmcclient.unbind_service(@service, @app_name)
      rescue
        puts "Service Failed to Unbind"
      end
    end
  
    def create_redis(service)
      @service = service
      begin
        @vmcclient.create_service('redis', @service)
        puts "Redis Service #{@service} Created"
      rescue
        puts "Redis Service Failed to Be Created"
      end
    end
    def create_mongo(service)
      @service = service
      begin
        @vmcclient.create_service('mongodb', @service)
        puts "MongoDB Service #{@service} Created"
      rescue
        puts "MongoDB Service Failed to Be Created"
      end
    end
    def create_rabbit(service)
      @service = service
      begin
        @vmcclient.create_service('rabbitmq', @service)
        puts "RabbitMQ Service #{@service} Created"
      rescue
        puts "RabbitMQ Service Failed to Be Created"
      end
    end
    def create_postgres(service)
      @service
      begin
        @vmcclient.create_service('postgresql', @service)
        puts "PostgreSQL Service #{@service} Created"
      rescue
        puts "PostgreSQL Service Failed to Be Create"
      end
    end
    def create_app(name,type, *args)
      $currentname = name
      @name = name
      @type = type
      if args[0] != nil then 
        arg = args[0]
        arg.each do |key,value|
          if key == "memory" then
            @memory = value
          end
          if key == "path" then
            @path = value
          end
          if key == "location" then
            @location = value
          end
          if key == "upload" then
            @upload = value
          end
          if key == "start" then
            @start = value
          end
        end
      end
      if @path == nil then
        @path = $target.delete('api')
        @uri = "#{@name}#{@path}"
      else
        @uri = "#{@name}#{@path}"
      end
      if @memory == nil then
        case @type
        when "sinatra"
          @memory = 128
        when "rails"
          @memory = 256
        when "spring"
          @memory = 512
        when "grails"
          @memory = 512
        when "roo"
          @memory = 512
        when "javaweb"
          @memory = 512
        when "node"
          @memory = 64
        else
          @memory = 256
        end
      end
      case @type
      when "rails"
        @framework = "rails3"
      when "spring"
        @framework = "spring"
      when "grails"
        @framework = "grails"
      when "roo"
        @framework = "spring"
      when "javaweb"
        @framework = "spring"
      when "sinatra"
        @framework = "sinatra"
      when "node"
        @framework = "node"
      else
        @framework = "unknown"
      end
      if @location == nil then
        @location = "./#{@name}"
      end
      manifest = {"name"=>@name, "staging"=>{"framework"=>@framework, "runtime"=>nil}, "uris"=>[@uri], "instances"=>1, "resources"=>{"memory"=>@memory}}
      @vmcclient.create_app(@name,manifest)
      if @upload == true then
        @vmcclient.upload_app(@name,@location)
      end
      if @start == true then
        @vmcclient.start_app(@name)
      end
    end

    def upload_app(name=$currentname,location="./#{$currentname}")
      unless get_files_to_pack(@location).empty?
        zipfile = "#{Dir.tmpdir}/#{name}.zip"
        pack(location, zipfile)
        @vmcclient.upload_app(name, zipfile)
      end
    end

    def get_files_to_pack(dir)
      Dir.glob("#{dir}/**/*", File::FNM_DOTMATCH).select do |f|
        process = true
        PACK_EXCLUSION_GLOBS.each { |e| process = false if File.fnmatch(e, File.basename(f)) }
        process && File.exists?(f)
      end
    end

    def pack(dir, zipfile)
      File::delete("#{zipfile}") if File::exists?("#{zipfile}")
      Zip::ZipFile::open(zipfile, true) do |zf|
        get_files_to_pack(dir).each do |f|
          zf.add(f.sub("#{dir}/",''), f)
        end
      end
    end
    
    def unpack(file, dest)
      Zip::ZipFile.foreach(file) do |zentry|
        epath = "#{dest}/#{zentry}"
        dirname = File.dirname(epath)
        FileUtils.mkdir_p(dirname) unless File.exists?(dirname)
        zentry.extract(epath) unless File.exists?(epath)
      end
    end
    
    def start_app(name=$currentname)
      appstate = @vmcclient.app_info(name)
      if appstate[:state] != 'STARTED' then
        appstate[:state] = 'STARTED'
        @vmcclient.update_app(name, appstate)
      end
    end

    def stop_app(name=$currentname)
      appstate = @vmcclient.app_info(name)
      if appstate[:state] != 'STOPPED' then
        appstate[:state] = 'STOPPED'
        @vmcclient.update_app(name, appstate)
      end
    end
    
    def delete_app(name)
      @vmcclient.delete_app(name)
    end
    
    def app_instances(instances, name=$currentname)
      app = @vmcclient.app_info(name)
      instances = instances.to_i
      current_instances = app[:instances]
      new_instances = current_instances + instances
      err "There must be at least 1 instance." if new_instances < 1
      if current_instances == new_instances then
        return
      end
      app[:instances] = new_instances
      client.update_app(name, app)
    end
    
    def get_instances(name=$currentname)
      app = @vmcclient.app_info(name)
      app[:instances]
    end
    
    def get_app(name,path='/')
      open(name, 'wb') do |getfile|
        getfile.print open(path).read
      end
    end
    
  end
end
  