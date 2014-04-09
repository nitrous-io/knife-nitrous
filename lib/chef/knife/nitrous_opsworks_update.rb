module KnifeNitrous
  class NitrousOpsworksUpdate < Chef::Knife
    include Chef::Knife::NitrousBase
    include KnifeNitrous::AWS

    banner    'knife nitrous opsworks update'
    category  'nitrous opsworks'

    option :s3_bucket,
      short: "-b BUCKET",
      long:  "--s3_bucket BUCKET",
      description: "S3 bucket to use for uploading artifacts in form 'foobar' (not URI format)"

    def run
      load_credentials!

      if config[:s3_bucket].nil?
        ui.error "You have not provided an S3 bucket to use for uploading artifacts (-b)."
        exit 1
      end

      announce("#{ENV['USER']} is updating data bags for OpsWorks.")

      puts "===> " + ui.color("Uploading #{data_bags.length} data bag items to S3 bucket #{config[:s3_bucket]}", :green)
      timestamp = Time.now.to_i
      s3_bucket = storage.directories.new(key: config[:s3_bucket])

      data_bags.each do |db|
        puts "===> " + ui.color("Uploading #{db} to #{config[:s3_bucket]}", :green)
        begin
          file = s3_bucket.files.create(
            key:    db,
            body:   File.open(db),
            public: false
          )
        rescue => e
          announce("Failed upload of #{db} to #{config[:s3_bucket]}.", level: :error)
          raise e
        end
      end

      announce("Uploaded all data bags to #{config[:s3_bucket]}", level: :success)
    end

  end
end
