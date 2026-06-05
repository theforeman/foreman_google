require 'test_google_helper'

module GoogleExtensions
  class AttachedDiskTest < GoogleTestCase
    describe 'insert_attrs' do
      it 'with source image' do
        disk = Google::Cloud::Compute::V1::AttachedDisk.new(source: 'source-image')
        assert_equal 'source-image', disk.insert_attrs[:source_image]
      end

      it 'without source image' do
        disk = Google::Cloud::Compute::V1::AttachedDisk.new
        assert_empty disk.insert_attrs[:source_image]
      end

      it 'includes device_name as name' do
        disk = Google::Cloud::Compute::V1::AttachedDisk.new(device_name: 'boot-disk', disk_size_gb: 30)
        attrs = disk.insert_attrs
        assert_equal 'boot-disk', attrs[:name]
        assert_equal 30, attrs[:size_gb]
      end
    end

    describe '#size_gb' do
      it 'returns disk_size_gb' do
        disk = Google::Cloud::Compute::V1::AttachedDisk.new(disk_size_gb: 50)
        assert_equal 50, disk.size_gb
      end
    end

    describe '#persisted?' do
      it 'returns nil' do
        disk = Google::Cloud::Compute::V1::AttachedDisk.new
        assert_nil disk.persisted?
      end
    end

    describe '#id' do
      it 'returns nil' do
        disk = Google::Cloud::Compute::V1::AttachedDisk.new
        assert_nil disk.id
      end
    end

    describe '#_delete' do
      it 'returns nil' do
        disk = Google::Cloud::Compute::V1::AttachedDisk.new
        assert_nil disk._delete
      end
    end
  end
end
