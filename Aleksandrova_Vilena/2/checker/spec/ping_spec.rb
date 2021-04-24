# frozen_string_literal: true

require 'rspec'

require_relative '../lib/ping'

RSpec.describe Ping do
  describe '#run' do
    let(:file) { File.expand_path('../data/rails_test_200.csv', __dir__) }
    subject { described_class.new(file, subdomains: true) }

    context 'errors' do
      before { subject.run }
      it 'file does not exist' do
        expect { subject.file_exist?('xxxx.csv') }.to raise_error(ArgumentError)
      end
    end

    context '--subdomains filter' do
      before { subject.run }
      it '1 response' do
        expect(subject.responses.count).to eq 1
      end
      it 'OK msg' do
        expect(subject.responses.at(0).msg).to eq 'OK'
      end
      it '200 HTTP status' do
        expect(subject.responses.at(0).code).to eq 200
      end
    end

    context '--opensource filter' do
      let(:file) { File.expand_path('../data/rails_test_os.csv', __dir__) }
      subject { described_class.new(file, opensource: true) }
      before { subject.run }
      it 'empty response' do
        expect(subject.responses.count).to eq 0
      end
    end

    context '--parallel filter' do
      let(:file) { File.expand_path('../data/rails_test_summary.csv', __dir__) }
      subject { described_class.new(file, parallel: '3') }
      before { subject.run }
      it 'checks the number of threads' do
        expect(subject.pool_size).to eq 3
      end
    end

    context '--filter KEYWORD' do
      let(:file) { File.expand_path('../data/rails_test_200.csv', __dir__) }
      subject { described_class.new(file, filter: 'WINNIEPOOH') }
      before { subject.run }
      it 'did not find a keyword WINNIEPOOH' do
        expect(subject.responses.count).to eq 0
      end
    end

    context 'summary equals' do
      let(:file) { File.expand_path('../data/rails_test_summary.csv', __dir__) }
      subject { described_class.new(file, {}) }
      before { subject.run }
      it 'summary equals' do
        expect(subject.responses.count).to eq 4
        expect(subject.responses.count(&:error?)).not_to eq 0
        expect(subject.responses.count(&:success?)).to eq 2
        expect(subject.responses.count(&:fail?)).to eq 1
        expect(subject.responses.select(&:error?).at(0).time).to eq nil
        expect(subject.responses.select(&:error?).at(0).msg).not_to eq nil
      end
    end
  end
end