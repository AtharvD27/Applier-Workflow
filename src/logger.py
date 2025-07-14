# src/logger.py
import logging
from pathlib import Path
from datetime import datetime

def setup_logger(name="stealth_logger", log_to_file=True, log_dir="output/logs"):
    """
    Setup a centralized logger with both console and file output.
    
    Args:
        name (str): Logger name (used for file naming if log_to_file=True)
        log_to_file (bool): Whether to create a log file
        log_dir (str): Directory to store log files
    
    Returns:
        logging.Logger: Configured logger instance
    """
    logger = logging.getLogger(name)
    logger.setLevel(logging.INFO)
    
    # Clear any existing handlers to avoid duplicates
    logger.handlers.clear()
    
    # Create formatter
    formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
    
    # Console handler (always present)
    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    # Optional file handler
    if log_to_file:
        log_path_obj = Path(log_dir)
        log_path_obj.mkdir(parents=True, exist_ok=True)
        
        # Create unique log file with timestamp
        log_file = log_path_obj / f"{name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
        
        file_handler = logging.FileHandler(log_file)
        file_handler.setFormatter(formatter)
        logger.addHandler(file_handler)
    
    return logger

def log_and_print(logger, level, message):
    """
    Enhanced logging function that handles both file and console output through logger handlers.
    Maintains the existing emoji and formatting style.
    
    Args:
        logger: Logger instance
        level (str): Log level ('INFO', 'ERROR', 'WARNING', 'DEBUG')
        message (str): Message to log
    """
    # Map string levels to logger methods
    level_methods = {
        "INFO": logger.info,
        "ERROR": logger.error,
        "WARNING": logger.warning,
        "DEBUG": logger.debug
    }
    
    # Log using the appropriate level - handlers will take care of console/file output
    if level in level_methods:
        level_methods[level](message)
    else:
        logger.info(message)  # Default to info if unknown level

# For backward compatibility - functions that can be imported directly
def get_logger(name="stealth_logger"):
    """Get or create a logger instance - for shared logger scenarios"""
    return logging.getLogger(name)

def create_file_logger(name, log_dir="output/logs"):
    """Create a logger that only logs to file (no console output)"""
    logger = logging.getLogger(f"{name}_file_only")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()
    
    log_path_obj = Path(log_dir)
    log_path_obj.mkdir(parents=True, exist_ok=True)
    log_file = log_path_obj / f"{name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
    
    file_handler = logging.FileHandler(log_file)
    file_handler.setFormatter(logging.Formatter("%(asctime)s [%(levelname)s] %(message)s"))
    logger.addHandler(file_handler)
    
    return logger