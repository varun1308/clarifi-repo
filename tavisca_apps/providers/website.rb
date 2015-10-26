use_inline_resources

action :add do
	
	website_directory = "#{new_resource.website_base_directory}\\#{new_resource.website_name}"
	
	app_pool_name = new_resource.website_name
	# Download the built application and unzip it to the app directory.

	app_checkout = Chef::Config["file_cache_path"] + "\\#{new_resource.website_name}"

	Chef::Log.debug "Downloading app source file using info #{new_resource.scm}."

	opsworks_scm_checkout new_resource.website_name do
	    destination      app_checkout
	    repository       new_resource.scm[:url]
	    revision         new_resource.scm[:revision]
	    user             new_resource.scm[:user]
	    password         new_resource.scm[:password]
	    ssh_key          new_resource.scm[:ssh_key]
	    type             new_resource.scm[:type]
  	end

  	
	if new_resource.should_replace_web_config
		Chef::Log.debug "Moving file #{new_resource.new_web_config}."
		powershell_script 'copy_web_config' do
		  code <<-EOH 
		     Copy-Item "#{app_checkout}\\#{new_resource.new_web_config}" "#{app_checkout}\\web.config" -Force
		  EOH
		end
	else
		unless new_resource.web_erb_config.empty? 
			Chef::Log.debug "web.config params #{new_resource.web_config_params}."

		 	template "#{app_checkout}\\web.config" do
		 	  local true
			  source "#{app_checkout}\\#{new_resource.web_erb_config}"
			  variables(
			  		:connection_strings => new_resource.web_config_params[:connection_strings]
			  )
			end
	 	
		else
			Chef::Log.debug "Did not find any web config replacement configuration."
		end
	end

		# Copy app to deployment directory
	execute "copy #{new_resource.website_name}" do
		command "Robocopy.exe #{app_checkout} #{website_directory} /MIR /XF .gitignore /XF web.config.erb /XD .git"
		returns [0, 1, 3]
	end
	
	# Create the site app pool.
	iis_pool  new_resource.website_name do
	  runtime_version new_resource.runtime_version
	end

	# Create the site directory and give IIS_IUSRS read rights.
	directory website_directory do
	  rights :read, 'IIS_IUSRS'
	  recursive true
	  action :create
	end

	

	# Create the app site.
	iis_site new_resource.website_name do
	  protocol new_resource.protocol
	  port new_resource.port
	  path website_directory
	  application_pool new_resource.website_name
	  host_header new_resource.host_header
	  action [:add, :start]
	end	
end