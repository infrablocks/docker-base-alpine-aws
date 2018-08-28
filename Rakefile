require 'rake_docker'
require 'rake_terraform'
require 'yaml'
require 'git'
require 'semantic'

require_relative 'lib/version'

def latest_tag
  Git.open('.').tags.map do |tag|
    Semantic::Version.new(tag.name)
  end.max
end

namespace :image do
  RakeDocker.define_image_tasks do |t|
    t.image_name = 'alpine-aws'
    t.work_directory = 'build/images'

    t.copy_spec = [
        "src/alpine-aws/Dockerfile",
    ]

    t.repository_name = 'alpine-aws'
    t.repository_url = 'infrablocks/alpine-aws'

    t.credentials = YAML.load_file(
        "config/secrets/dockerhub/credentials.yaml")

    t.tags = [latest_tag.to_s, 'latest']
  end
end

namespace :version do
  task :bump, [:type] do |_, args|
    next_tag = latest_tag.send("#{args.type}!")
    repo.add_tag(next_tag.to_s)
    repo.push('origin', 'master', tags: true)
  end
end
