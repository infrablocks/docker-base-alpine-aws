# frozen_string_literal: true

require 'rake_docker'
require 'rake_circle_ci'
require 'rake_github'
require 'rake_ssh'
require 'rake_gpg'
require 'rake_terraform'
require 'securerandom'
require 'yaml'
require 'git'
require 'os'
require 'pathname'
require 'semantic'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

require_relative 'lib/version'

Docker.options = {
  read_timeout: 300
}

def repo
  Git.open(Pathname.new('.'))
end

def latest_tag
  repo.tags.map do |tag|
    Semantic::Version.new(tag.name)
  end.max
end

def tmpdir
  base = (ENV['TMPDIR'] || '/tmp')
  OS.osx? ? "/private#{base}" : base
end

task default: %i[
  test:code:fix
  test:integration
]

namespace :encryption do
  namespace :passphrase do
    desc 'Generate encryption passphrase for CI GPG key'
    task :generate do
      File.write('config/secrets/ci/encryption.passphrase',
                 SecureRandom.base64(36))
    end
  end
end

namespace :keys do
  namespace :deploy do
    RakeSSH.define_key_tasks(
      path: 'config/secrets/ci/',
      comment: 'maintainers@infrablocks.io'
    )
  end

  namespace :gpg do
    RakeGPG.define_generate_key_task(
      output_directory: 'config/secrets/ci',
      name_prefix: 'gpg',
      owner_name: 'InfraBlocks Maintainers',
      owner_email: 'maintainers@infrablocks.io',
      owner_comment: 'docker-base-alpine-aws CI Key'
    )
  end
end

RakeCircleCI.define_project_tasks(
  namespace: :circle_ci,
  project_slug: 'github/infrablocks/docker-base-alpine-aws'
) do |t|
  circle_ci_config =
    YAML.load_file('config/secrets/circle_ci/config.yaml')

  t.api_token = circle_ci_config['circle_ci_api_token']
  t.environment_variables = {
    ENCRYPTION_PASSPHRASE:
        File.read('config/secrets/ci/encryption.passphrase')
            .chomp
  }
  t.checkout_keys = []
  t.ssh_keys = [
    {
      hostname: 'github.com',
      private_key: File.read('config/secrets/ci/ssh.private')
    }
  ]
end

RakeGithub.define_repository_tasks(
  namespace: :github,
  repository: 'infrablocks/docker-base-alpine-aws'
) do |t, args|
  github_config =
    YAML.load_file('config/secrets/github/config.yaml')

  t.access_token = github_config['github_personal_access_token']
  t.deploy_keys = [
    {
      title: 'CircleCI',
      public_key: File.read('config/secrets/ci/ssh.public')
    }
  ]
  t.branch_name = args.branch_name
  t.commit_message = args.commit_message
end

namespace :pipeline do
  desc 'Prepare CircleCI Pipeline'
  task prepare: %i[
    circle_ci:project:follow
    circle_ci:env_vars:ensure
    circle_ci:checkout_keys:ensure
    circle_ci:ssh_keys:ensure
    github:deploy_keys:ensure
  ]
end

namespace :image do
  RakeDocker.define_image_tasks(
    image_name: 'alpine-aws'
  ) do |t|
    t.work_directory = 'build/images'

    t.copy_spec = [
      'src/alpine-aws/Dockerfile'
    ]

    t.repository_name = 'alpine-aws'
    t.repository_url = 'infrablocks/alpine-aws'

    t.credentials = YAML.load_file(
      'config/secrets/dockerhub/credentials.yaml'
    )

    t.tags = [latest_tag.to_s, 'latest']
  end
end

RuboCop::RakeTask.new

namespace :test do
  namespace :code do
    desc 'Run all checks on the test code'
    task check: [:rubocop]

    desc 'Attempt to automatically fix issues with the test code'
    task fix: [:'rubocop:auto_correct']
  end

  RSpec::Core::RakeTask.new(integration: [
                              'image:build'
                            ])
end

namespace :version do
  desc 'Bump version for specified type (pre, major, minor, patch)'
  task :bump, [:type] do |_, args|
    next_tag = latest_tag.send("#{args.type}!")
    repo.add_tag(next_tag.to_s)
    repo.push('origin', 'main', tags: true)
  end

  desc 'Release gem'
  task :release do
    next_tag = latest_tag.release!
    repo.add_tag(next_tag.to_s)
    repo.push('origin', 'main', tags: true)
  end
end
