from __future__ import annotations

import pytest

from api.auth.tokens import create_access_token, decode_access_token
import jwt


def test_access_token_includes_and_validates_iss_aud(monkeypatch):
    monkeypatch.setenv('JWT_SECRET', 'test-secret')
    monkeypatch.setenv('JWT_ISSUER', 'app')
    monkeypatch.setenv('JWT_AUDIENCE', 'app')

    token = create_access_token(subject='123', email='a@b.com', ttl_minutes=5)
    payload = decode_access_token(token)
    assert payload['iss'] == 'app'
    assert payload['aud'] == 'app'


def test_decode_rejects_wrong_issuer(monkeypatch):
    monkeypatch.setenv('JWT_SECRET', 'test-secret')
    monkeypatch.setenv('JWT_ISSUER', 'issuer-a')
    monkeypatch.setenv('JWT_AUDIENCE', 'aud')

    token = create_access_token(subject='123', email='a@b.com', ttl_minutes=5)
    monkeypatch.setenv('JWT_ISSUER', 'issuer-b')

    with pytest.raises(jwt.InvalidTokenError):
        decode_access_token(token)


def test_decode_rejects_wrong_audience(monkeypatch):
    monkeypatch.setenv('JWT_SECRET', 'test-secret')
    monkeypatch.setenv('JWT_ISSUER', 'issuer')
    monkeypatch.setenv('JWT_AUDIENCE', 'aud-a')

    token = create_access_token(subject='123', email='a@b.com', ttl_minutes=5)
    monkeypatch.setenv('JWT_AUDIENCE', 'aud-b')

    with pytest.raises(jwt.InvalidTokenError):
        decode_access_token(token)
