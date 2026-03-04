"""Tests for provider configuration loading and model resolution."""

import pytest
import yaml

from ingest.providers import ProviderConfig, load_config, resolve_model


@pytest.fixture()
def config_yaml():
    """Return a minimal provider config dict."""
    return {
        "providers": {
            "deepseek": {
                "base_url": "https://api.deepseek.com/v1",
                "env_key": "DEEPSEEK_API_KEY",
                "models": ["deepseek-chat"],
            },
            "gemini": {
                "base_url": "https://generativelanguage.googleapis.com/v1beta/openai/",
                "env_key": "GEMINI_API_KEY",
                "models": ["gemini-2.5-flash"],
            },
        }
    }


@pytest.fixture()
def config_file(tmp_path, config_yaml):
    """Write config to a temp YAML file and return the path."""
    path = tmp_path / "providers.yaml"
    path.write_text(yaml.dump(config_yaml))
    return str(path)


class TestLoadConfig:
    def test_loads_and_parses(self, config_file):
        config = load_config(config_file)
        assert "deepseek" in config
        assert config["deepseek"]["base_url"] == "https://api.deepseek.com/v1"
        assert config["deepseek"]["env_key"] == "DEEPSEEK_API_KEY"
        assert config["deepseek"]["models"] == ["deepseek-chat"]

    def test_missing_file_raises(self, tmp_path):
        with pytest.raises(FileNotFoundError):
            load_config(str(tmp_path / "nonexistent.yaml"))

    def test_missing_providers_key_raises(self, tmp_path):
        path = tmp_path / "bad.yaml"
        path.write_text(yaml.dump({"not_providers": {}}))
        with pytest.raises(ValueError, match="providers"):
            load_config(str(path))


class TestResolveModel:
    def test_valid_resolution(self, config_yaml, monkeypatch):
        monkeypatch.setenv("DEEPSEEK_API_KEY", "sk-test-123")
        config = config_yaml["providers"]

        result = resolve_model("deepseek/deepseek-chat", config)

        assert isinstance(result, ProviderConfig)
        assert result.base_url == "https://api.deepseek.com/v1"
        assert result.api_key == "sk-test-123"
        assert result.model == "deepseek-chat"

    def test_missing_env_var(self, config_yaml, monkeypatch):
        monkeypatch.delenv("DEEPSEEK_API_KEY", raising=False)
        config = config_yaml["providers"]

        with pytest.raises(ValueError, match="DEEPSEEK_API_KEY"):
            resolve_model("deepseek/deepseek-chat", config)

    def test_invalid_format_no_slash(self, config_yaml):
        config = config_yaml["providers"]

        with pytest.raises(ValueError, match="provider/model"):
            resolve_model("deepseek-chat", config)

    def test_unknown_provider(self, config_yaml):
        config = config_yaml["providers"]

        with pytest.raises(ValueError, match="Unknown provider.*openai"):
            resolve_model("openai/gpt-4", config)

    def test_unknown_model(self, config_yaml, monkeypatch):
        monkeypatch.setenv("DEEPSEEK_API_KEY", "sk-test-123")
        config = config_yaml["providers"]

        with pytest.raises(ValueError, match="Unknown model.*no-such-model.*deepseek"):
            resolve_model("deepseek/no-such-model", config)

    def test_second_provider(self, config_yaml, monkeypatch):
        monkeypatch.setenv("GEMINI_API_KEY", "gem-key-456")
        config = config_yaml["providers"]

        result = resolve_model("gemini/gemini-2.5-flash", config)

        assert result.base_url == "https://generativelanguage.googleapis.com/v1beta/openai/"
        assert result.api_key == "gem-key-456"
        assert result.model == "gemini-2.5-flash"
