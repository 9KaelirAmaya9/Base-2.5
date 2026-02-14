from digital_ocean.scripts.python.logging import logger


def test_logger_info(caplog):
    with caplog.at_level("INFO"):
        logger.info("Test info message")
    assert "Test info message" in caplog.text
