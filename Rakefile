# frozen_string_literal: true

require 'git'
require 'os'
require 'pathname'
require 'rake_docker'
require 'rake_factory/kernel_extensions'
require 'rake_git'
require 'rake_git_crypt'
require 'rake_github'
require 'rake_gpg'
require 'rake_slack'
require 'rake_terraform'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'securerandom'
require 'semantic'
require 'yaml'

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
  base = ENV['TMPDIR'] || '/tmp'
  OS.osx? ? "/private#{base}" : base
end

task default: %i[
  test:code:fix
  test:integration
]

RakeGitCrypt.define_standard_tasks(
  namespace: :git_crypt,

  provision_secrets_task_name: :'secrets:provision',
  destroy_secrets_task_name: :'secrets:destroy',

  install_commit_task_name: :'git:commit',
  uninstall_commit_task_name: :'git:commit',

  gpg_user_key_paths: %w[
    config/gpg
    config/secrets/ci/gpg.public
  ]
)

namespace :git do
  RakeGit.define_commit_task(
    argument_names: [:message]
  ) do |t, args|
    t.message = args.message
  end
end

namespace :encryption do
  namespace :directory do
    desc 'Ensure CI secrets directory exists.'
    task :ensure do
      FileUtils.mkdir_p('config/secrets/ci')
    end
  end

  namespace :passphrase do
    desc 'Generate encryption passphrase for CI GPG key'
    task generate: ['directory:ensure'] do
      File.write(
        'config/secrets/ci/encryption.passphrase',
        SecureRandom.base64(36)
      )
    end
  end
end

namespace :keys do
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

namespace :secrets do
  namespace :directory do
    desc 'Ensure secrets directory exists and is set up correctly'
    task :ensure do
      FileUtils.mkdir_p('config/secrets')
      unless File.exist?('config/secrets/.unlocked')
        File.write('config/secrets/.unlocked', 'true')
      end
    end
  end

  desc 'Generate all generatable secrets.'
  task generate: %w[
    encryption:passphrase:generate
    keys:gpg:generate
  ]

  desc 'Provision all secrets.'
  task provision: [:generate]

  desc 'Delete all secrets.'
  task :destroy do
    rm_rf 'config/secrets'
  end

  desc 'Rotate all secrets.'
  task rotate: [:'git_crypt:reinstall']
end

namespace :library do
  desc 'Run all checks of the library'
  task check: [:rubocop]

  desc 'Attempt to automatically fix issues with the library'
  task fix: [:'rubocop:autocorrect_all']
end

RakeGithub.define_repository_tasks(
  namespace: :github,
  repository: 'infrablocks/docker-base-alpine-aws'
) do |t|
  # Operator's ambient auth. Resolve once and fail fast: a missing,
  # unauthenticated, or absent gh yields an empty string, which would
  # otherwise surface later as an opaque Octokit 401.
  github_token = ENV.fetch('GITHUB_TOKEN') do
    `gh auth token`
  rescue Errno::ENOENT
    ''
  end.strip
  if github_token.empty?
    raise 'No GitHub token available: set GITHUB_TOKEN or run `gh auth login`'
  end

  t.access_token = github_token

  # Actions store only: dependabot runs never reach the passphrase — the
  # only pr.yaml job that unlocks git-crypt (prerelease) is guarded to
  # same-repo human PRs. Guard against a locked clone: without
  # it, File.read returns git-crypt ciphertext and github:secrets:ensure
  # silently uploads garbage that only surfaces much later as an opaque
  # GPG unlock failure in the release job.
  passphrase = File.binread('config/secrets/ci/encryption.passphrase')
  if passphrase.start_with?("\x00GITCRYPT")
    raise 'encryption.passphrase is git-crypt ciphertext — unlock the ' \
          'clone before provisioning'
  end
  t.secrets = [
    { name: 'ENCRYPTION_PASSPHRASE', value: passphrase.chomp }
  ]
  t.environments = [
    { name: 'release',
      reviewers: [{ team: 'maintainers' }] }
  ]
end

namespace :slack do
  RakeSlack.define_notification_tasks do |t|
    t.bot_token = ENV.fetch('SLACK_BOT_TOKEN', nil)
    t.routing_rules = [
      { when: { type: 'on_hold' },
        channel: 'C038EDCRSQJ', format: :on_hold },  # release
      { when: { actor: 'dependabot[bot]', outcome: 'success' },
        channel: 'C03N711HVDG', format: :success },  # builds-dependabot
      { when: { actor: 'dependabot[bot]' },
        channel: 'C03N711HVDG', format: :failure },  # builds-dependabot
      { when: { outcome: 'success' },
        channel: 'C023XUE76GH', format: :success },  # builds
      # Failures go to builds, not team-dev (org default), to keep noise
      # out of a popular channel while this pipeline beds in.
      { when: {},
        channel: 'C023XUE76GH', format: :failure } # builds
    ]
  end
end

namespace :repository do
  desc 'Set the git author for CI'
  task :set_ci_author do
    sh 'git config --global user.name "InfraBlocks CI"'
    sh 'git config --global user.email "ci@infrablocks.io"'
  end
end

namespace :pipeline do
  desc 'Prepare GitHub Actions pipeline'
  task prepare: %i[
    github:secrets:ensure
    github:environments:ensure
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

    t.credentials = dynamic do
      if File.binread('config/secrets/dockerhub/credentials.yaml')
             .start_with?("\x00GITCRYPT")
        nil # tree locked: skip Docker Hub auth (base image is public)
      else
        YAML.load_file('config/secrets/dockerhub/credentials.yaml')
      end
    end

    t.platform = 'linux/amd64'

    t.tags = [latest_tag.to_s, 'latest']
  end
end

RuboCop::RakeTask.new

namespace :test do
  namespace :code do
    desc 'Run all checks on the test code'
    task check: [:rubocop]

    desc 'Attempt to automatically fix issues with the test code'
    task fix: [:'rubocop:autocorrect_all']
  end

  RSpec::Core::RakeTask.new(:unit)

  RSpec::Core::RakeTask.new(integration: [
                              'image:build'
                            ]) do |t|
    t.rspec_opts = %w[--format documentation]
  end
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

namespace :prerelease do
  desc 'Build and publish a PR-namespaced pre-release image (PR CI only)'
  task :publish, %i[pr_number run_number run_attempt] do |_, args|
    # PR image tag: the version main's prerelease would publish next
    # (latest_tag bumped by the family's prerelease type — normally rc),
    # plus a collision-free per-run suffix in the family's tag grammar.
    # Docker tags forbid '+', so we reuse the semver '-'/'.'-separated
    # form and no build metadata. No git tag is created, pushed, or
    # committed — unlike version:bump this only ever tags the built image.
    pr_tag = "#{latest_tag.rc!}.pr#{args.pr_number}" \
             ".#{args.run_number}.#{args.run_attempt}"

    Rake::Task['image:build'].invoke

    credentials =
      unless File.binread('config/secrets/dockerhub/credentials.yaml')
                 .start_with?("\x00GITCRYPT")
        YAML.load_file('config/secrets/dockerhub/credentials.yaml')
      end
    Docker.authenticate!(credentials) if credentials

    image = Docker::Image.all(filter: 'alpine-aws').first
    raise RakeDocker::ImageNotFound, 'alpine-aws image not built' if image.nil?

    image.tag(repo: 'infrablocks/alpine-aws', tag: pr_tag,
              force: true)
    # repo_tag must be explicit: without it docker-api resolves the
    # push repository from the image object's cached RepoTags.first
    # (the bare local build tag, e.g. 'alpine-aws:latest'), so the
    # push targets docker.io/library/<name> where the PR tag does not
    # exist. The tag: option only sets the tag, never the repository.
    image.push(nil,
               repo_tag: "infrablocks/alpine-aws:#{pr_tag}") do |chunk|
      RakeDocker::Output.print chunk
    end

    puts "Published infrablocks/alpine-aws:#{pr_tag}"
  end
end
