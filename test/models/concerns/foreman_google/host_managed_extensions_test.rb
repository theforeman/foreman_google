require 'test_google_helper'

module ForemanGoogle
  class HostManagedExtensionsTest < GoogleTestCase
    let(:host_class) do
      Class.new do
        include ForemanGoogle::HostManagedExtensions
        attr_accessor :vm
      end
    end

    describe '#ip_addresses' do
      it 'returns vm ip_addresses when vm exists' do
        vm = mock('GoogleCompute')
        vm.expects(:ip_addresses).returns(['1.2.3.4', '10.0.0.1'])

        host = host_class.new
        host.vm = vm
        assert_equal ['1.2.3.4', '10.0.0.1'], host.ip_addresses
      end

      it 'returns empty array when vm is nil' do
        host = host_class.new
        host.vm = nil
        assert_empty host.ip_addresses
      end
    end

    describe '#vm_ip_address' do
      it 'returns vm public IP when vm exists' do
        vm = mock('GoogleCompute')
        vm.expects(:vm_ip_address).returns('1.2.3.4')

        host = host_class.new
        host.vm = vm
        assert_equal '1.2.3.4', host.vm_ip_address
      end

      it 'returns nil when vm is nil' do
        host = host_class.new
        host.vm = nil
        assert_nil host.vm_ip_address
      end
    end
  end
end
