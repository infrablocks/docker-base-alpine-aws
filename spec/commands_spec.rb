require 'spec_helper'

describe 'commands' do
  before(:all) do
    set :backend, :docker
    set :docker_image, "alpine-aws:latest"
  end

  ['python3', 'py3-pip'].each do |apk|
    it "includes #{apk}" do
      expect(package(apk)).to be_installed
    end
  end

  it "includes the AWS CLI" do
    expect(command('aws --version').stdout)
        .to(match(/1.18.124/))
  end
end
