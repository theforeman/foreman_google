class ForemanGceToForemanGoogleGce < ActiveRecord::Migration[6.0]
  def up
    User.without_auditing do
      old_type = 'Foreman::Model::GCE'
      new_type = 'ForemanGoogle::GCE'
      compute_resources = ComputeResource.unscoped.where(type: old_type)

      compute_resources.each do |cr|
        json_data = File.read(cr.attrs[:key_path])
        cr.update(type: new_type, password: json_data)
      end
    end
  end
end
