import time

import pytest
from celery import Celery
from celery.exceptions import TimeoutError as CeleryTimeoutError

from api.tasks import app as celery_app


pytestmark = [pytest.mark.integration]


def test_celery_add_runs_quickly():
    assert isinstance(celery_app, Celery)
    res = celery_app.send_task('app.add', args=[2, 3])
    deadline = time.monotonic() + 30
    last_error = None
    while time.monotonic() < deadline:
        try:
            out = res.get(timeout=5)
            assert out == 5
            return
        except CeleryTimeoutError as exc:
            last_error = exc
            time.sleep(0.5)

    pytest.fail(f'Celery task timed out: {last_error}')
