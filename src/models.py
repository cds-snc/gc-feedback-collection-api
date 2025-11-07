"""
Data models for Problem and TopTask feedback collections.
Converted from C# classes to Python dataclasses for MongoDB storage.
"""

from dataclasses import dataclass, field
from typing import List, Optional
from datetime import datetime


@dataclass
class Problem:
    """Problem feedback model for MongoDB 'problem' collection."""

    time_stamp: str = ""
    problem_date: str = ""
    url: str = ""
    language: str = ""
    opposite_lang: str = ""
    title: str = ""
    institution: str = ""
    theme: str = ""
    section: str = ""
    problem: str = ""
    problem_details: str = ""
    yesno: str = ""
    device_type: str = ""
    browser: str = ""
    contact: str = ""
    processed: str = "false"
    air_table_sync: str = "false"
    personal_info_processed: str = "false"
    auto_tag_processed: str = "false"
    data_origin: str = ""
    tags: List[str] = field(default_factory=list)

    def to_dict(self):
        """Convert to dictionary for MongoDB insertion."""
        return {
            "timeStamp": self.time_stamp,
            "problemDate": self.problem_date,
            "url": self.url,
            "language": self.language,
            "oppositeLang": self.opposite_lang,
            "title": self.title,
            "institution": self.institution,
            "theme": self.theme,
            "section": self.section,
            "problem": self.problem,
            "problemDetails": self.problem_details,
            "yesno": self.yesno,
            "deviceType": self.device_type,
            "browser": self.browser,
            "contact": self.contact,
            "processed": self.processed,
            "airTableSync": self.air_table_sync,
            "personalInfoProcessed": self.personal_info_processed,
            "autoTagProcessed": self.auto_tag_processed,
            "dataOrigin": self.data_origin,
            "tags": self.tags,
        }


@dataclass
class OriginalProblem:
    """Original problem record for archival purposes."""

    time_stamp: str = ""
    problem_date: str = ""
    url: str = ""
    language: str = ""
    opposite_lang: str = ""
    title: str = ""
    institution: str = ""
    theme: str = ""
    section: str = ""
    problem: str = ""
    problem_details: str = ""
    yesno: str = ""
    device_type: str = ""
    browser: str = ""
    contact: str = ""
    data_origin: str = ""

    @classmethod
    def from_problem(cls, problem: Problem):
        """Create OriginalProblem from Problem instance."""
        return cls(
            time_stamp=problem.time_stamp,
            problem_date=problem.problem_date,
            url=problem.url,
            language=problem.language,
            opposite_lang=problem.opposite_lang,
            title=problem.title,
            institution=problem.institution,
            theme=problem.theme,
            section=problem.section,
            problem=problem.problem,
            problem_details=problem.problem_details,
            yesno=problem.yesno,
            device_type=problem.device_type,
            browser=problem.browser,
            contact=problem.contact,
            data_origin=problem.data_origin,
        )

    def to_dict(self):
        """Convert to dictionary for MongoDB insertion."""
        return {
            "timeStamp": self.time_stamp,
            "problemDate": self.problem_date,
            "url": self.url,
            "language": self.language,
            "oppositeLang": self.opposite_lang,
            "title": self.title,
            "institution": self.institution,
            "theme": self.theme,
            "section": self.section,
            "problem": self.problem,
            "problemDetails": self.problem_details,
            "yesno": self.yesno,
            "deviceType": self.device_type,
            "browser": self.browser,
            "contact": self.contact,
            "dataOrigin": self.data_origin,
        }


@dataclass
class TopTask:
    """TopTask survey feedback model for MongoDB 'toptasksurvey' collection."""

    date_time: str = ""
    time_stamp: str = ""
    survey_referrer: str = ""
    language: str = ""
    device: str = ""
    screener: str = ""
    dept: str = ""
    theme: str = ""
    theme_other: str = ""
    grouping: str = ""
    task: str = ""
    task_other: str = ""
    task_satisfaction: str = ""
    task_ease: str = ""
    task_completion: str = ""
    task_improve: str = ""
    task_improve_comment: str = ""
    task_why_not: str = ""
    task_why_not_comment: str = ""
    task_sampling: str = ""
    sampling_invitation: str = ""
    sampling_gc: str = ""
    sampling_canada: str = ""
    sampling_theme: str = ""
    sampling_institution: str = ""
    sampling_grouping: str = ""
    sampling_task: str = ""
    processed: str = "false"
    top_task_air_table_sync: str = "false"
    personal_info_processed: str = "false"
    auto_tag_processed: str = "false"

    def to_dict(self):
        """Convert to dictionary for MongoDB insertion."""
        return {
            "dateTime": self.date_time,
            "timeStamp": self.time_stamp,
            "surveyReferrer": self.survey_referrer,
            "language": self.language,
            "device": self.device,
            "screener": self.screener,
            "dept": self.dept,
            "theme": self.theme,
            "themeOther": self.theme_other,
            "grouping": self.grouping,
            "task": self.task,
            "taskOther": self.task_other,
            "taskSatisfaction": self.task_satisfaction,
            "taskEase": self.task_ease,
            "taskCompletion": self.task_completion,
            "taskImprove": self.task_improve,
            "taskImproveComment": self.task_improve_comment,
            "taskWhyNot": self.task_why_not,
            "taskWhyNotComment": self.task_why_not_comment,
            "taskSampling": self.task_sampling,
            "samplingInvitation": self.sampling_invitation,
            "samplingGC": self.sampling_gc,
            "samplingCanada": self.sampling_canada,
            "samplingTheme": self.sampling_theme,
            "samplingInstitution": self.sampling_institution,
            "samplingGrouping": self.sampling_grouping,
            "samplingTask": self.sampling_task,
            "processed": self.processed,
            "topTaskAirTableSync": self.top_task_air_table_sync,
            "personalInfoProcessed": self.personal_info_processed,
            "autoTagProcessed": self.auto_tag_processed,
        }
