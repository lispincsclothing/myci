class Project < ActiveRecord::Base
  has_many :builds, :dependent => :destroy

  BuildInstructions = Struct.new(:prepare_cmds, :ci_cmds)

  def workspace_path
    Rails.root.join("workspace", "project-#{self.id}-#{self.repo.gsub(/\//, '-')}")
  end

  def prepare_commands
    instructions.prepare_cmds
  end

  def ci_commands
    instructions.ci_cmds
  end

  def repo_uri
    "https://#{github_host}/#{repo}"
  end

  def api_uri
    if github_host == "github.com"
      "https://api.github.com"
    else
      "https://#{github_host}/api/v3"
    end
  end

  def has_file? filename
    File.exist?(workspace_file filename)
  end

  def workspace_file filename
    File.join(workspace_path, filename)
  end

  def instructions
    instructions = BuildInstructions.new

    if has_file?('dciy.toml')
      settings = TOML.load_file(workspace_file 'dciy.toml')

      h = settings['dciy'] || {}
      cmds = h['commands'] || {}

      instructions.prepare_cmds = cmds['prepare']
      instructions.ci_cmds = cmds['cibuild']
    end

    cibuild_file_path = Rails.root.join('script/cibuild')

    puts "HELOO "
    if instructions.ci_cmds.nil? && has_file?(cibuild_file_path)
      instructions.ci_cmds = [cibuild_file_path]
    end

    # Default to no preparation commands.
    instructions.prepare_cmds ||= []

    # Ensure that we've figured out how to build the project, either from
    # dciy.toml or from a script/cibuild command. If neither are given,
    # blow up!
    if instructions.ci_cmds.nil? || instructions.ci_cmds.empty?
      raise CantFindBuildFile.new
    end

    instructions
  end
end

class CantFindBuildFile < RuntimeError ; end
