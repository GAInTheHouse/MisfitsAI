class CreateSolidInfrastructure < ActiveRecord::Migration[8.0]
  def change
    instance_eval(File.read(Rails.root.join("tmp/solid_queue.rb")), __FILE__, __LINE__)
    instance_eval(File.read(Rails.root.join("tmp/solid_cable.rb")), __FILE__, __LINE__)
    instance_eval(File.read(Rails.root.join("tmp/solid_cache.rb")), __FILE__, __LINE__)
  end
end
