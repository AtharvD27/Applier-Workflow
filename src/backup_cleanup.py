#!/usr/bin/env python3
"""
Backup & Cleanup Script for Job Scraper Data

This script:
1. Creates backups of old job data (older than 2 weeks)
2. Archives old log files
3. Removes old entries from active CSV files
4. Maintains clean, recent data for active scraping

Usage:
    python backup_cleanup.py [--dry-run] [--keep-weeks N]
"""

import os
import pandas as pd
import argparse
from datetime import datetime, timedelta
from pathlib import Path
import zipfile
import yaml

# ── Centralized Logging ──────────────────────────────────────────
from logger import setup_logger, log_and_print

def load_config():
    """Load configuration to get file paths"""
    try:
        with open("config/scraper_config.yaml", "r") as f:
            return yaml.safe_load(f)
    except FileNotFoundError:
        # Default paths if config not found
        return {
            "main_csv_file": "output/jobs.csv",
            "filtered_csv_file": "output/final_ml_jobs.csv",
            "log_dir": "output/logs"
        }

def create_backup_structure(backup_root="backups"):
    """Create backup directory structure"""
    backup_dir = Path(backup_root)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    current_backup = backup_dir / f"backup_{timestamp}"
    
    # Create directories
    (current_backup / "csv_files").mkdir(parents=True, exist_ok=True)
    (current_backup / "logs").mkdir(parents=True, exist_ok=True)
    
    return current_backup

def get_cutoff_date(weeks_to_keep=2):
    """Calculate the cutoff date (2 weeks ago by default)"""
    return datetime.now() - timedelta(weeks=weeks_to_keep)

def parse_date_column(date_str):
    """Parse date string from CSV (handles multiple formats)"""
    if pd.isna(date_str) or date_str == "":
        return None
    
    try:
        # Try MM/DD/YYYY format first
        if "/" in str(date_str):
            return datetime.strptime(str(date_str), "%m/%d/%Y")
        # Try other common formats
        elif "-" in str(date_str):
            return datetime.strptime(str(date_str), "%Y-%m-%d")
        else:
            return None
    except ValueError:
        return None

def backup_and_clean_csv(file_path, backup_dir, cutoff_date, logger, dry_run=False):
    """Backup old entries and remove them from the main CSV"""
    if not os.path.exists(file_path):
        log_and_print(logger, "WARNING", f"⚠️  CSV file not found: {file_path}")
        return 0, 0
    
    log_and_print(logger, "INFO", f"📂 Processing CSV: {file_path}")
    
    try:
        # Load CSV
        df = pd.read_csv(file_path)
        original_count = len(df)
        log_and_print(logger, "INFO", f"   📊 Loaded {original_count} total entries")
        
        if original_count == 0:
            log_and_print(logger, "INFO", f"   ✅ Empty file, nothing to process")
            return 0, 0
        
        # Parse dates and identify old entries
        if "date_added" in df.columns:
            df["parsed_date"] = df["date_added"].apply(parse_date_column)
            
            # Separate old and recent entries
            old_mask = df["parsed_date"] < cutoff_date
            old_entries = df[old_mask].copy()
            recent_entries = df[~old_mask].copy()
            
            # Remove the temporary parsed_date column
            old_entries = old_entries.drop("parsed_date", axis=1)
            recent_entries = recent_entries.drop("parsed_date", axis=1)
            
        else:
            log_and_print(logger, "WARNING", f"   ⚠️  No 'date_added' column found, skipping date-based filtering")
            return 0, 0
        
        old_count = len(old_entries)
        recent_count = len(recent_entries)
        
        log_and_print(logger, "INFO", f"   📅 Entries older than {cutoff_date.strftime('%m/%d/%Y')}: {old_count}")
        log_and_print(logger, "INFO", f"   📅 Recent entries to keep: {recent_count}")
        
        if old_count > 0:
            # Save old entries to backup
            backup_file = backup_dir / "csv_files" / f"{Path(file_path).stem}_old_entries.csv"
            
            if not dry_run:
                old_entries.to_csv(backup_file, index=False)
                log_and_print(logger, "INFO", f"   💾 Backed up {old_count} old entries to: {backup_file}")
                
                # Update main CSV with only recent entries
                recent_entries.to_csv(file_path, index=False)
                log_and_print(logger, "INFO", f"   🗑️  Removed {old_count} old entries from main file")
                log_and_print(logger, "INFO", f"   ✅ Kept {recent_count} recent entries")
            else:
                log_and_print(logger, "INFO", f"   🔍 [DRY RUN] Would backup {old_count} entries and keep {recent_count}")
        
        else:
            log_and_print(logger, "INFO", f"   ✅ No old entries to remove")
        
        return old_count, recent_count
        
    except Exception as e:
        log_and_print(logger, "ERROR", f"   ❌ Error processing {file_path}: {str(e)}")
        return 0, 0

def backup_old_logs(log_dir, backup_dir, cutoff_date, logger, dry_run=False):
    """Backup and optionally remove old log files"""
    log_dir_path = Path(log_dir)
    if not log_dir_path.exists():
        log_and_print(logger, "WARNING", f"⚠️  Log directory not found: {log_dir}")
        return 0
    
    log_and_print(logger, "INFO", f"📁 Processing logs in: {log_dir}")
    
    log_files = list(log_dir_path.glob("*.log"))
    old_logs = []
    
    for log_file in log_files:
        # Get file modification time
        file_mtime = datetime.fromtimestamp(log_file.stat().st_mtime)
        if file_mtime < cutoff_date:
            old_logs.append(log_file)
    
    log_and_print(logger, "INFO", f"   📊 Total log files: {len(log_files)}")
    log_and_print(logger, "INFO", f"   📅 Old log files (before {cutoff_date.strftime('%m/%d/%Y')}): {len(old_logs)}")
    
    if old_logs:
        if not dry_run:
            # Create a zip file of old logs
            logs_backup_zip = backup_dir / "logs" / "old_logs.zip"
            
            with zipfile.ZipFile(logs_backup_zip, 'w', zipfile.ZIP_DEFLATED) as zipf:
                for log_file in old_logs:
                    zipf.write(log_file, log_file.name)
            
            log_and_print(logger, "INFO", f"   📦 Archived {len(old_logs)} old logs to: {logs_backup_zip}")
            
            # Remove old log files
            for log_file in old_logs:
                log_file.unlink()
            
            log_and_print(logger, "INFO", f"   🗑️  Removed {len(old_logs)} old log files")
        else:
            log_and_print(logger, "INFO", f"   🔍 [DRY RUN] Would archive and remove {len(old_logs)} old log files")
    else:
        log_and_print(logger, "INFO", f"   ✅ No old log files to archive")
    
    return len(old_logs)

def create_backup_summary(backup_dir, csv_stats, logs_archived, cutoff_date, logger):
    """Create a summary file of the backup operation"""
    summary_file = backup_dir / "backup_summary.txt"
    
    with open(summary_file, "w") as f:
        f.write("BACKUP SUMMARY\n")
        f.write("=" * 50 + "\n")
        f.write(f"Backup Date: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Cutoff Date: {cutoff_date.strftime('%Y-%m-%d')} (data older than this was archived)\n")
        f.write(f"Backup Location: {backup_dir}\n\n")
        
        f.write("CSV FILES PROCESSED:\n")
        f.write("-" * 30 + "\n")
        total_archived = 0
        total_kept = 0
        
        for file_path, (archived, kept) in csv_stats.items():
            f.write(f"File: {file_path}\n")
            f.write(f"  - Entries archived: {archived}\n")
            f.write(f"  - Entries kept: {kept}\n")
            total_archived += archived
            total_kept += kept
        
        f.write(f"\nTOTAL CSV ENTRIES:\n")
        f.write(f"  - Total archived: {total_archived}\n")
        f.write(f"  - Total kept active: {total_kept}\n\n")
        
        f.write(f"LOG FILES:\n")
        f.write(f"  - Old log files archived: {logs_archived}\n\n")
        
        f.write("BACKUP STRUCTURE:\n")
        f.write("-" * 20 + "\n")
        f.write(f"{backup_dir}/\n")
        f.write(f"├── csv_files/\n")
        f.write(f"│   ├── jobs_old_entries.csv\n")
        f.write(f"│   └── final_ml_jobs_old_entries.csv\n")
        f.write(f"├── logs/\n")
        f.write(f"│   └── old_logs.zip\n")
        f.write(f"└── backup_summary.txt\n")
    
    log_and_print(logger, "INFO", f"📋 Created backup summary: {summary_file}")

def main():
    """Main backup and cleanup function"""
    parser = argparse.ArgumentParser(description="Backup and cleanup old job scraper data")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done without making changes")
    parser.add_argument("--keep-weeks", type=int, default=2, help="Number of weeks of data to keep (default: 2)")
    
    args = parser.parse_args()
    
    # Setup centralized logger for backup cleanup (always independent)
    logger = setup_logger(name="backup_cleanup", log_to_file=True)
    
    try:
        log_and_print(logger, "INFO", "🚀 Starting backup and cleanup process")
        
        if args.dry_run:
            log_and_print(logger, "INFO", "🔍 Running in DRY RUN mode - no changes will be made")
        
        # Load configuration
        config = load_config()
        cutoff_date = get_cutoff_date(args.keep_weeks)
        
        log_and_print(logger, "INFO", f"📅 Cutoff date: {cutoff_date.strftime('%Y-%m-%d %H:%M:%S')}")
        log_and_print(logger, "INFO", f"📅 Keeping data from the last {args.keep_weeks} weeks")
        
        # Create backup directory structure
        if not args.dry_run:
            backup_dir = create_backup_structure()
            log_and_print(logger, "INFO", f"📁 Created backup directory: {backup_dir}")
        else:
            backup_dir = Path("backups/dry_run")
        
        # Process CSV files
        csv_files = [
            config["main_csv_file"],
            config["filtered_csv_file"]
        ]
        
        csv_stats = {}
        total_archived = 0
        total_kept = 0
        
        for csv_file in csv_files:
            archived, kept = backup_and_clean_csv(csv_file, backup_dir, cutoff_date, logger, args.dry_run)
            csv_stats[csv_file] = (archived, kept)
            total_archived += archived
            total_kept += kept
        
        # Process log files
        logs_archived = backup_old_logs(config["log_dir"], backup_dir, cutoff_date, logger, args.dry_run)
        
        # Create backup summary
        if not args.dry_run and (total_archived > 0 or logs_archived > 0):
            create_backup_summary(backup_dir, csv_stats, logs_archived, cutoff_date, logger)
        
        # Final summary
        log_and_print(logger, "INFO", "🎉 Backup and cleanup completed!")
        log_and_print(logger, "INFO", f"   📊 Total CSV entries archived: {total_archived}")
        log_and_print(logger, "INFO", f"   📊 Total CSV entries kept active: {total_kept}")
        log_and_print(logger, "INFO", f"   📁 Log files archived: {logs_archived}")
        
        if not args.dry_run and (total_archived > 0 or logs_archived > 0):
            log_and_print(logger, "INFO", f"   💾 Backup saved to: {backup_dir}")
        elif args.dry_run:
            log_and_print(logger, "INFO", "   🔍 This was a dry run - no actual changes made")
        else:
            log_and_print(logger, "INFO", "   ✅ No old data found to archive")
        
    except Exception as e:
        log_and_print(logger, "ERROR", f"💥 Backup process failed: {str(e)}")
        logger.error("Full error details:", exc_info=True)
        raise

if __name__ == "__main__":
    main()