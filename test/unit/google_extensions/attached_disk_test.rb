require 'test_google_helper'
require 'rbconfig'

module GoogleExtensions
  class AttachedDiskTest < GoogleTestCase
    describe 'plugin loading' do
      it 'loads AttachedDisk through the plugin entrypoint' do
        helper = ForemanGoogle::Engine.root.join('test', 'test_google_helper').to_s
        script = <<~RUBY
          require 'bundler/setup'
          require "#{helper}"
          require 'foreman_google'
          abort 'missing AttachedDisk' unless defined?(Google::Cloud::Compute::V1::AttachedDisk)
        RUBY

        assert system({ 'BUNDLE_GEMFILE' => ForemanGoogle::Engine.root.join('Gemfile').to_s }, RbConfig.ruby, '-e', script)
      end
    end

    describe 'insert_attrs' do
      it 'with source image' do
        disk = Google::Cloud::Compute::V1::AttachedDisk.new(source: 'source-image')
        assert_equal 'source-image', disk.insert_attrs[:source_image]
      end

      it 'without source image' do
        disk = Google::Cloud::Compute::V1::AttachedDisk.new
        assert_empty disk.insert_attrs[:source_image]
      end
    end
  end
end
