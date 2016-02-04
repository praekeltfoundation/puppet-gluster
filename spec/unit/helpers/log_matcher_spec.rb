require 'rspec/matchers/fail_matchers'

RSpec.configure do |config|
  config.include RSpec::Matchers::FailMatchers
end

class Logger
  include Puppet::Util::Logging
end

describe 'log_matcher' do
  before :each do
    @log = Logger.new
  end

  it 'finds a message by string' do
    expect { @log.notice('foo!') }.to have_logged('foo!')
    expect { @log.debug('foo!') }.to have_logged(['foo!', :debug])
    expect { @log.warning('foo!') }.to have_logged(['foo!', :warning])
    expect {
      expect { @log.info('foo!') }.to have_logged('foo')
    }.to fail_with('no logged messages match "foo"')
  end

  it 'finds a message by regex' do
    expect { @log.notice('Pity the fool!') }.to have_logged(/foo/)
    expect { @log.debug('Pity the fool!') }.to have_logged([/foo/, :debug])
    expect { @log.warning('Pity the fool!') }.to have_logged([/foo/, :warning])
    expect {
      expect { @log.info('Pity the foal!') }.to have_logged(/foo/)
    }.to fail_with('no logged messages match /foo/')
  end

  it 'finds a message with an arbitrary matcher' do
    expect { @log.notice('Bad thing') }.to have_logged(start_with('Bad'))
    expect { @log.debug('Bad thing') }.to have_logged([end_with('ng'), :debug])
  end

  it 'finds multiple messages' do
    expect {
      @log.notice('Millenium hand and shrimp')
      @log.info('Bad thing')
      @log.debug('Pity the fool!')
    }.to have_logged(
      [/foo/, :debug],
      'Millenium hand and shrimp',
      [start_with('Bad'), :info],
      end_with('ng'))
  end

  it 'does not find a message logged at the wrong level' do
    expect {
      expect { @log.info('Pity the fool!') }.to have_logged([/foo/, :warning])
    }.to fail_with('no logged warning messages match /foo/')
    expect {
      expect { @log.info('Pity the fool!') }.to have_logged([/foo/, :debug])
    }.to fail_with('no logged debug messages match /foo/')
  end

  it 'emits a useful message on failure' do
    expect {
      expect {}.to have_logged(/foo/)
    }.to fail_with('no logged messages match /foo/')
    expect {
      expect {}.to have_logged([/foo/, :debug])
    }.to fail_with('no logged debug messages match /foo/')
  end

  it 'reports the first expected message it fails to find' do
    expect {
      expect {
        @log.notice('Millenium hand and shrimp')
        @log.info('Good thing')
        @log.debug('Pity the fool!')
      }.to have_logged(
        [/foo/, :debug],
        'Millenium hand and shrimp',
        [/^Bad/, :info],
        end_with('gn'))
    }.to fail_with('no logged info messages match /^Bad/')
  end
end
