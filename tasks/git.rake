module GitCommands
  class ShellError < RuntimeError; end
 
  @logging = ENV['LOGGING'] != "false"
 
  def self.run cmd, *expected_exitstatuses
    puts "+ #{cmd}" if @logging
    output = `#{cmd} 2>&1`
    puts output.gsub(/^/, "- ") if @logging
    expected_exitstatuses << 0 if expected_exitstatuses.empty?
    raise ShellError.new("ERROR: '#{cmd}' failed with exit status #{$?.exitstatus}") unless
      [expected_exitstatuses].flatten.include?( $?.exitstatus )
    output
  end
 
  def self.current_branch
    run("git branch --no-color | grep '*' | cut -d ' ' -f 2").chomp
  end
 
  def self.remote_branch_exists?(branch)
    ! run("git branch -r --no-color | grep '#{branch}'").blank?
  end
 
  def self.ensure_clean_working_directory!
    return if run("git status", 0, 1).match(/working directory clean/)
    raise "Must have clean working directory"
  end
 
  def self.diff_staging
    puts run("git diff HEAD origin/staging")
  end
 
  def self.diff_production
    puts run("git diff origin/staging origin/production")
  end

  def self.push(src_branch, dst_branch)
    raise "origin/#{dst_branch} branch does not exist" unless remote_branch_exists?("origin/#{dst_branch}")
    ensure_clean_working_directory!
    begin
      run "git fetch"
      run "git push -f origin #{src_branch}:#{dst_branch}"
    rescue
      puts "Pushing #{src_branch} to origin/#{dst_branch} failed."
      raise
    end
  end
 
  def self.push_staging
    push(current_branch, "staging")
  end
 
  def self.push_production
    push("origin/staging", "production")
  end
 
  def self.branch_production(branch)
    raise "You must specify a branch name." if branch.blank?
    ensure_clean_working_directory!
    run "git fetch"
    run "git branch -f #{branch} origin/production"
    run "git checkout #{branch}"
  end
 
  def self.tag(dst_branch, tag, msg="")
    raise "origin/#{dst_branch} branch does not exist" unless remote_branch_exists?("origin/#{dst_branch}")
    ensure_clean_working_directory!
    begin
      run "git fetch"
      run "git tag -a #{tag} -m '#{msg}' #{dst_branch}"
      run "git push --tags"
    rescue
      puts "Tagging #{dst_branch} with #{tag} failed!"
      raise
    end
  end

  def self.latest_tag(dst_branch)
    run "git fetch --tags"
    begin
      run "git describe #{dst_branch}"
    rescue
      puts "There are no tags on #{dst_branch}"
    end
  end

  def self.pull_template
    ensure_clean_working_directory!
    run "git pull git://github.com/thoughtbot/suspenders.git master"
  end
end
 
namespace :git do
  namespace :push do
    desc "Reset origin's staging branch to be the current branch."
    task :staging do
      GitCommands.push_staging
    end
 
    desc "Reset origin's production branch to origin's staging branch."
    task :production do
      GitCommands.push_production
    end
  end
 
  namespace :diff do
    desc "Show the difference between current branch and origin/staging."
    task :staging do
      GitCommands.diff_staging
    end
 
    desc "Show the difference between origin/staging and origin/production."
    task :production do
      GitCommands.diff_production
    end
  end
 
  namespace :pull do
    desc "Pull updates from suspenders, the thoughtbot rails template."
    task :suspenders do
      GitCommands.pull_template
    end
  end
 
  namespace :branch do
    desc "Branch origin/production into BRANCH locally."
    task :production do
      GitCommands.branch_production(branch)
    end
  end

  namespace :tag do
    desc "Tags the production branch (you will be prompted for a tag and message)"
    task :production do
      puts "The latest tag in production is..."
      GitCommands.latest_tag "production"
      
      print "Specify a new tag (can't start with a number or have spaces, i.e. v0.17.1) : "
      tag = STDIN.gets.strip
      
      print "Enter a description (optional) : "
      msg = STDIN.gets.strip
      msg = "Tagging release #{tag}" if msg.blank?

      GitCommands.tag "production", tag, msg
    end

    namespace :production do
      desc "get the latest tag in production"
      task :latest do
        GitCommands.latest_tag "production"
      end
    end
  end
end
