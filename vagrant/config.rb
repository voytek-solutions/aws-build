require 'yaml'

def getConfig()
	localConfig = { }
	configFile = getConfigFolder() + "/.vagrant.yml"
	configFiles = [
		getConfigFolder() + "/../../../vagrant/base.yml",
		getConfigFolder() + "/.vagrant.base.yml",
		configFile
	]

	while localConfig.empty? do
		configFileName = configFiles.pop
		if File.file?(configFileName)
			localConfig = YAML.load_file(configFileName)
			print("Configuration loaded from #{configFileName}\n")
		end
	end

	# This function needs to be defined in your Vagrantfile
	# We will call it every time to make sure we have all latest options
	configSetup(localConfig)

	file = File.open(configFile, 'w')
	file.write(YAML.dump(localConfig))
	file.close

	# include machines global config
	machines = YAML.load_file(getConfigFolder() + '/../../../vagrant/machines.yml')

	localConfig.deep_merge!(machines)
end

# Read a file, returning nil if it doesn't exist
def readfile(filename)
	filename = File.expand_path(filename, File.dirname(__FILE__))
	File.read(filename)
rescue
	nil
end

def getInput(prompt, config, key, default=nil, description=nil)
	if config.key?(key) && ! config[key].to_s.empty?
		return
	end

	prompt = "#{prompt}\n#{description}\n   " if description
	prompt = "#{prompt} [#{default}]" if default
	print " o  #{prompt}: "
	input = STDIN.gets.strip
	if input.empty? and default
		input = default
	elsif input.empty?
		raise "Field is required, try again"
	end
	config[key] = input
end

def getInputNumber(prompt, config, key, default=nil)
	if config.key?(key) && ! config[key].to_s.empty?
		return
	end

	prompt = "#{prompt} [#{default}]" if default
	print "#{prompt}: "
	input = STDIN.gets.strip
	if input.empty? and default
		input = default
	elsif input.empty?
		raise "Field is required, try again"
	end
	config[key] = input.to_i
end

def getYesNo(prompt, config, key, default = nil)
	if config.key?(key) && ! config[key].to_s.empty?
		return
	end

	yesNo = nil
	while yesNo.nil?
		if default == 'y'
			print "#{prompt} [Y/n]: "
		elsif default == 'n'
			print "#{prompt} [y/N]: "
		else
			print "#{prompt} [y/n]: "
		end

		response = STDIN.gets.downcase
		if response.strip == ''
			response = default
		end

		if response.strip == 'y'
			yesNo = true
		elsif response.strip == 'n'
			yesNo = false
		else
			print "\nPlease Enter y or n\n"
		end
	end

	config[key] = yesNo
end

def getOption(prompt, config, key, options)
	if config.key?(key) && ! config[key].to_s.empty?
		return
	end

	selectedOption = nil

	print "#{prompt}\n"
	while selectedOption.nil?
		options.each_index do |optionIndex|
			print "  #{optionIndex} - #{options[optionIndex][:text]}\n"
		end
		print "please select number 0 .. #{options.length - 1}: "

		input = STDIN.gets.strip
		selectedOption = input.to_i

		if selectedOption > options.length
			selectedOption = nil
		end
	end

	config[key] = options[selectedOption][:value]
end

##
# return full path for
def location(dir)
	dir = File.expand_path(dir)
	if !File.directory? dir
		FileUtils::mkpath(dir)
	end
	return dir
end
