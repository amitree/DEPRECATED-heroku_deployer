require 'amitree/heroku_client'

describe Amitree::HerokuClient do
  before do
    @client = Amitree::HerokuClient.new('api_key', 'my-staging-app', 'my-prod-app')
  end

  describe '#staging_release_version' do
    it "should return the name of the staging release if production was promoted from staging" do
      expect(@client.staging_release_version({'description' => 'Promote my-staging-app v123 deadbeef'})).to eq 123
    end

    it "should raise an error if production was not promoted from staging" do
      expect {
        @client.staging_release_version({'description' => 'Add newrelic:wayne add-on'})
      }.to raise_error(Amitree::HerokuClient::Error)
    end
  end

  describe '#staging_releases_since' do
    before do
      expect(@client).to receive(:get_releases).with('my-staging-app').and_return([{'version' => 100}, {'version' => 101}, {'version' => 102}, {'version' => 103}])
    end

    it "should return all releases since the specified release" do
      expect(@client.staging_releases_since('description' => 'Promote my-staging-app v101 deadbeef')).to match_array [{'version' => 102}, {'version' => 103}]
    end

    it "should raise an error if the specified release cannot be found" do
      expect {
        @client.staging_releases_since('description' => 'Promote my-staging-app v104 deadbeef')
        }.to raise_error(Amitree::HerokuClient::Error)
    end

    it "should return an empty array if the specified release is the last one" do
      expect(@client.staging_releases_since('description' => 'Promote my-staging-app v103 deadbeef')).to eq []
    end
  end

  describe '#deploy_to_production' do

  end

  describe '#db_migrate_on_production' do
    before do
      @attempts = 0
      allow(@client).to receive(:heroku_run) do |app, cmd|
        @cmd = cmd
        @attempts += 1
        raise StandardError if @attempts <= num_failures
      end
    end

    context 'with no failures' do
      let(:num_failures) { 0 }
      let(:options) { {} }
      before do
        @client.db_migrate_on_production(options)
      end
      it 'should succeed' do
        expect(@attempts).to eq 1
      end
      it 'should run the default rake task' do
        expect(@cmd).to eq 'rake db:migrate db:seed'
      end
      context 'with a single additional rake task' do
        let(:options) { {rake: 'do:something:else'} }
        it 'should run a single additional rake task if requested' do
          expect(@cmd).to eq 'rake db:migrate db:seed do:something:else'
        end
      end
      context 'with several additional rake tasks' do
        let(:options) { {rake: ['do:something', 'else']} }
        it 'should run additional rake tasks if requested' do
          expect(@cmd).to eq 'rake db:migrate db:seed do:something else'
        end
      end
    end

    [1,2].each do |n|
      context "with #{n} failures" do
        let(:num_failures) { n }
        it 'should retry, but still raise PostDeploymentError' do
          expect { @client.db_migrate_on_production }.to raise_error Amitree::HerokuClient::PostDeploymentError
          expect(@attempts).to eq n+1
        end

        it 'should set the cause of the PostDeploymentError correctly' do
          begin
            @client.db_migrate_on_production
          rescue Amitree::HerokuClient::PostDeploymentError => e
            error = e
          end

          expect(error.cause).to be_a StandardError
        end
      end
    end

    context 'with 3 failures' do
      let(:num_failures) { 3 }
      it 'should raise the underlying error' do
        expect { @client.db_migrate_on_production }.to raise_error StandardError
        expect(@attempts).to eq 3
      end
    end
  end

  describe '#version' do
    it 'should return the version string' do
      expect(@client.version('version' => 123)).to eq 'v123'
    end
  end
end
