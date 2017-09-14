class SeedDump
  module Environment

    def dump_using_environment(env = {})
      Rails.application.eager_load!

      models_env = env['MODEL'] || env['MODELS']

      # Handle mongoid
      mongo = env['MONGO'] == 'true'
      if mongo
        mongo_tables = Mongoid.default_session.collections.map(&:name).join(",")
        models_env = env['MODEL'] || env['MODELS'] || mongo_tables
      else
        models_env = env['MODEL'] || env['MODELS']
      end
      models_with_empties = if models_env
                 models_env.split(',')
                   .collect do |x|
                    y = x.strip.underscore.singularize.camelize
                    begin
                      y.constantize
                    rescue NameError => err
                    end
                 end
               else
                 ActiveRecord::Base.descendants
               end

      models = models_with_empties.reject(&:nil?)
      models = models.select do |model|
                 (model.to_s != 'ActiveRecord::SchemaMigration') && \
                 (mongo ? true : model.table_exists?) && \
                  model.exists?
               end

      append = (env['APPEND'] == 'true')

      models_exclude_env = env['MODELS_EXCLUDE']
      if models_exclude_env
        models_exclude_env.split(',')
                          .collect do |x|
                            y = x.strip.underscore.singularize.camelize
                            begin
                              y.constantize
                            rescue NameError => err

                            end
                          end
                          .each { |exclude| models.delete(exclude) }
      end

      models.each do |model|
        model = model.limit(env['LIMIT'].to_i) if env['LIMIT']

        SeedDump.dump(model,
                      append: append,
                      batch_size: (env['BATCH_SIZE'] ? env['BATCH_SIZE'].to_i : nil),
                      exclude: (env['EXCLUDE'] ? env['EXCLUDE'].split(',').map {|e| e.strip.to_sym} : nil),
                      file: (env['FILE'] || 'db/seeds.rb'),
                      import: (env['IMPORT'] == 'true'),
                      mongo: mongo)

        append = true
      end
    end
  end
end
