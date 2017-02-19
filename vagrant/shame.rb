##
# This is a SHAME file.
# If you don't know where to put your function, you put it here and clear it up next time.
#
# This file should be empty most of the time

def ensureDir(dir)
	dir = File.expand_path(dir)
	if !File.directory? dir
		FileUtils::mkpath(dir)
	end
	return dir
end

class ::Hash
	def deep_merge!(second)
		merger = proc { |key, v1, v2| Hash === v1 && Hash === v2 ? v1.merge!(v2, &merger) : v2 }
		self.merge!(second, &merger)
	end
end

def getBuildSteps(mode)
	build_steps = [
		{ 'play' => "playbook", 'tags' => [ "build", "download_application" ] },
		{ 'play' => "environment", 'tags' => [ "build", "configure" ] },
		{ 'play' => "playbook", 'tags' => [ "configure", "local_build" ] }
	]

	if mode == "build"
		build_steps = [
			{ 'play' => "playbook", 'tags' => [ "build" ] },
			{ 'play' => "environment", 'tags' => [ "build" ] },
		]
	end

	if mode == "configure"
		build_steps = [
			{ 'play' => "environment", 'tags' => [ "configure" ] },
			{ 'play' => "playbook", 'tags' => [ "configure" ] }
		]
	end

	return build_steps
end
