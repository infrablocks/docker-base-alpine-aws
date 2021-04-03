# frozen_string_literal: true

require 'spec_helper'

describe 'image' do
  before(:all) do
    set :backend, :docker
    set :docker_image, 'alpine-aws:latest'
  end

  it 'exposes AWS CLI version in the environment' do
    expect(command('env | grep AWS_CLI_VERSION').stdout)
      .to(match(/1.18.124/))
  end

  it 'runs as root' do
    expect(command('whoami').stdout)
      .to(match(/^root$/))
  end
end
