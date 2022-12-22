# frozen_string_literal: true

require 'spec_helper'

describe 'OS' do
  before(:all) do
    set :backend, :docker
    set :docker_image, 'alpine-aws:latest'
  end

  it 'is alpine 3.16' do
    expect(command('cat /etc/alpine-release').stdout)
      .to(match(/3.17/))
  end
end
