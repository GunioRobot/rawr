require 'fileutils'
require 'bundler'
require 'platform'

module Rawr
  class ExeBundler < Bundler  
    include FileUtils

    def create_bin_dir_for_linux(file_dir_name)
      chmod 0755, "#{file_dir_name}/launch4j/bin-linux/windres"
      chmod 0755, "#{file_dir_name}/launch4j/bin-linux/ld"
      sh "ln -s #{file_dir_name}/launch4j/bin-linux #{file_dir_name}/launch4j/bin"
    end

    def create_bin_dir_for_win(file_dir_name)
      FileUtils.rename "#{file_dir_name}/launch4j/bin-win #{file_dir_name}/launch4j/bin"
    end

    def create_bin_dir_for_mac(file_dir_name)
      chmod 0755, "#{file_dir_name}/launch4j/bin-mac/windres"
      chmod 0755, "#{file_dir_name}/launch4j/bin-mac/ld"
      sh "ln -s #{file_dir_name}/launch4j/bin-mac #{file_dir_name}/launch4j/bin"
    end

    def deploy(options)
      @project_name = options.project_name
      @classpath = options.classpath
      @main_java_class = options.main_java_file
      @built_jar_path = options.jar_output_dir

      @java_app_deploy_path = options.windows_output_dir
      @target_jvm_version = options.target_jvm_version
      @minimum_windows_jvm_version = options.minimum_windows_jvm_version
      @jvm_arguments = options.jvm_arguments

      @startup_error_message     = options.windows_startup_error_message
      @bundled_jre_error_message = options.windows_bundled_jre_error_message
      @jre_version_error_message = options.windows_jre_version_error_message
      @launcher_error_message    = options.windows_launcher_error_message
      @icon_path                 = options.windows_icon_path

      @launch4j_config_file = "#{@java_app_deploy_path}/configuration.xml"

      copy_deployment_to @java_app_deploy_path
      puts "Creating Windows application in #{@built_jar_path}/#{@project_name}.exe"

      File.open(@launch4j_config_file, 'w') do |file|
        file << <<-CONFIG_ENDL
<launch4jConfig>
<dontWrapJar>true</dontWrapJar>
<headerType>0</headerType>
<jar>#{@project_name}.jar</jar>
<outfile>#{@java_app_deploy_path}/#{@project_name}.exe</outfile>
<errTitle></errTitle>
<jarArgs></jarArgs>
<chdir></chdir>
<customProcName>true</customProcName>
<stayAlive>false</stayAlive>
<icon>#{@icon_path}</icon>
<jre>
  <path></path>
  <minVersion>#{@minimum_windows_jvm_version}.0</minVersion>
  <maxVersion></maxVersion>
  <initialHeapSize>0</initialHeapSize>
  <maxHeapSize>0</maxHeapSize>
  #{"<args>" + @jvm_arguments + "</args>" unless @jvm_arguments.nil? || @jvm_arguments.strip.empty?}
</jre>
<messages>
  <startupErr>#{@startup_error_message}</startupErr>
  <bundledJreErr>#{@bundled_jre_error_message}</bundledJreErr>
  <jreVersionErr>#{@jre_version_error_message}</jreVersionErr>
  <launcherErr>#{@launcher_error_message}</launcherErr>
</messages>
</launch4jConfig>          
CONFIG_ENDL
      end

      file_dir_name = File.dirname(__FILE__)

      # Set ACL permissions to allow launch4j bundler to run on Windows
      if Platform.instance.using_windows?
        # Check for FAT32 vs NTFS, the cacls command doesn't work on FAT32 nor is it required
        output = `fsutil fsinfo volumeinfo #{file_dir_name.split(':')[0]}:\\`
        # fsutil can only work with admin priviledges
        raise output if output =~ /requires that you have administrative privileges/
        # ===== Sample output of 'fsutil fsinfo volumeinfo c:\'
        # Volume Name :
        # Volume Serial Number : 0x80a5650a
        # Max Component Length : 255
        # File System Name : FAT32
        # Preserves Case of filenames
        # Supports Unicode in filenames
        if 'NTFS' == output.split("\n")[3].split(':')[1].strip
          sh "echo y | cacls \"#{file_dir_name }/launch4j/bin-mac/windres.exe\" /G \"#{ENV['USERNAME']}\":F"
          sh "echo y | cacls \"#{file_dir_name }/launch4j/bin-mac/ld.exe\" /G \"#{ENV['USERNAME']}\":F"
        end
      elsif Platform.instance.using_linux?
        create_bin_dir_for_linux file_dir_name
      elsif Platform.instance.using_mac?
        create_bin_dir_for_mac file_dir_name
      else
        create_bin_dir_for_win file_dir_name
      end

      warn "call: java -jar \"#{file_dir_name}/launch4j/launch4j.jar\" \"#{@launch4j_config_file}\""
      sh "java -jar \"#{file_dir_name}/launch4j/launch4j.jar\" \"#{@launch4j_config_file}\""
    end

  end
end
