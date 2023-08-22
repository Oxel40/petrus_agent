import Config

agent_secret =
  System.get_env("AGENT_SECRET") ||
    if config_env() != :prod do
      "testing"
    else
      raise """
      environment variable AGENT_SECRET is missing.
      """
    end

url =
  if config_env() != :prod do
    {'localhost', 4000, '/printer-agent/websocket'}
  else
    {'petrus.oxel.dev', 443, '/printer-agent/websocket'}
  end

config :petrus_agent, agent_secret: agent_secret
config :petrus_agent, url: url
