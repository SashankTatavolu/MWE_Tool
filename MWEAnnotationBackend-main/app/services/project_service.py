import datetime
import re

from flask import jsonify
from sqlalchemy import func

from app.models.annotation_model import Annotation
from app.models.user_model import User
from flask_mail import Message
from .. import db,mail
from ..models.project_model import Project
import xml.etree.ElementTree as ET
import html
import re
from indicnlp.tokenize import sentence_tokenize
from indicnlp.normalize.indic_normalize import IndicNormalizerFactory
import datetime
from ..models.sentence_model import Sentence
from sqlalchemy import func, case



# Map from UI language names to codes
LANG_MAP = {
    "English": "en",
    "Hindi": "hi",
    "Marathi": "mr",
    "Assamese": "as",
    "Boro": "brx",
    "Nepali": "ne",
    "Manipuri": "mni",
    "Bangla": "bn",
    "Maithili": "mai",
    "Konkani": "gom",
}

# Languages that IndicNLP can really handle
INDICNLP_LANGS = {"hi", "mr", "as", "bn"}

_NORMALIZER_FACTORY = IndicNormalizerFactory()
_NORMALIZERS = {}


def get_normalizer(lang_code: str):
    """Return cached IndicNLP normalizer for the language."""
    if lang_code not in _NORMALIZERS:
        _NORMALIZERS[lang_code] = _NORMALIZER_FACTORY.get_normalizer(lang_code)
    return _NORMALIZERS[lang_code]



def split_sentences_with_lang(raw_text: str, language_name: str):
    """
    Split sentences depending on language.
    - Hindi / Marathi / Assamese / Bangla -> IndicNLP
    - Manipuri -> custom split_manipuri_sentences
    - English -> NLTK (if available)
    - Others -> simple regex fallback
    """
    if not raw_text or not raw_text.strip():
        return []

    # Normalize newlines a bit
    raw_text = raw_text.replace("\r", "").strip()

    lang_code = LANG_MAP.get(language_name, "en")

    # 🔹 Special case: Manipuri
    if language_name == "Manipuri":
        return [s.strip() for s in split_manipuri_sentences(raw_text) if s.strip()]


    # 1) IndicNLP for supported Indic languages
    if lang_code in INDICNLP_LANGS:
        normalizer = get_normalizer(lang_code)
        normalized = normalizer.normalize(raw_text)
        sentences = sentence_tokenize.sentence_split(normalized, lang=lang_code)
        return [re.sub(r"\s+", " ", s).strip() for s in sentences if s and s.strip()]

    # 2) English – use NLTK if present
    if lang_code == "en" and en_sent_tokenize is not None:
        return [s.strip() for s in en_sent_tokenize(raw_text) if s.strip()]

    # 3) Fallback for other languages
    sentences = re.split(r"[।|॥|\.|\?|!]\s*", raw_text)
    return [s.strip() for s in sentences if s.strip()]

def create_project(data, current_user):
    print("Creating Project...")  # Debugging

    new_project = Project(
        title=data.get('title', 'Untitled Project'),
        description=data.get('description', ''),
        language=data.get('language', 'Unknown'),
        file_text=data.get('file_text', ''),  # Storing the raw content
        uploaded_by=current_user,
        uploaded_on=datetime.datetime.now()
    )

    db.session.add(new_project)
    db.session.flush()  # Get new_project.id before committing

    file_text = data['file_text'].strip()
    is_xml = file_text.startswith("<") and file_text.endswith(">")
    sentence_counter = 1  # Start numbering from 1 for this project

    if is_xml:
        print("Detected XML input.")  # Debugging
        try:
            root = ET.fromstring(file_text)  # Parse XML
            print("XML Parsed Successfully.")  # Debugging

            decoded_text = html.unescape(file_text)
            contains_inline_annotations = re.search(r'<(TIMEX|NUMEX)', decoded_text) is not None

            if contains_inline_annotations:
                print("Detected inline annotations. Processing OLD XML format.")
                for sentence_elem in root.findall(".//sentence"):
                    raw_text = sentence_elem.get("text", "").strip()
                    is_annotated = sentence_elem.get("isAnnotated") == "True"

                    print(f"Processing Sentence {sentence_counter}: {raw_text}")

                    decoded_text = html.unescape(raw_text)
                    annotations = []

                    def annotation_extractor(match):
                        annotation_type = match.group(1)
                        attributes = match.group(2)
                        annotated_word = html.unescape(match.group(3))

                        annotation_attrs = dict(re.findall(r'(\w+)="(.*?)"', attributes))
                        annotations.append({
                            'type': annotation_type,
                            'text': annotated_word,
                            'attributes': annotation_attrs
                        })

                        print(f"Extracted Annotation: {annotation_type} -> {annotated_word}")
                        return annotated_word

                    clean_text = re.sub(r'<(\w+)(.*?)>(.*?)</\1>', annotation_extractor, decoded_text)
                    print(f"Cleaned Sentence {sentence_counter}: {clean_text}")

                    sentence = Sentence(
                        sentence_number=sentence_counter,
                        content=clean_text,
                        is_annotated=is_annotated,
                        project_id=new_project.id
                    )
                    db.session.add(sentence)
                    db.session.flush()

                    if is_annotated:
                        for annotation in annotations:
                            annotation_id = annotation['attributes'].get('ID')
                            annotation_type = annotation['type']
                            annotation_subtype = annotation['attributes'].get('TYPE', '')
                            annotated_word = annotation['text']

                            print(f"Saving Annotation ID {annotation_id}: {annotation_type} ({annotation_subtype}) -> {annotated_word}")

                            annotation_record = Annotation(
                                word_phrase=annotated_word,
                                annotation=f"{annotation_type} ({annotation_subtype})",
                                annotated_by=current_user,
                                annotated_on=datetime.datetime.now(),
                                sentence_id=sentence.id,
                                project_id=new_project.id
                            )
                            db.session.add(annotation_record)

                    sentence_counter += 1  # Increment for next sentence
            
            else:
                print("Processing NEW Annotated XML format.")  # Debugging
                sentences_root = root.find("./sentences")
                if sentences_root is None:
                    raise ValueError("Invalid XML: <sentences> tag missing inside <project>.")
                
                for sentence_elem in sentences_root.findall(".//sentence"):
                    raw_text = sentence_elem.get("text", "").strip()
                    is_annotated = sentence_elem.get("isAnnotated") == "True"

                    print(f"Processing Sentence {sentence_counter}: {raw_text}")
                    
                    sentence = Sentence(
                        sentence_number=sentence_counter,
                        content=raw_text,
                        is_annotated=is_annotated,
                        project_id=new_project.id
                    )
                    db.session.add(sentence)
                    db.session.flush()

                    annotations_elem = sentence_elem.find("annotations")
                    if annotations_elem is not None:
                        for annotation_elem in annotations_elem.findall("annotation"):
                            annotation_id = annotation_elem.get("id")
                            annotated_word = annotation_elem.get("word_phrase")
                            annotation_type = annotation_elem.get("annotation")
                            annotated_by = annotation_elem.get("annotated_by")
                            annotated_on = annotation_elem.get("annotated_on")

                            print(f"Saving Annotation ID {annotation_id}: {annotation_type} -> {annotated_word}")

                            annotation_record = Annotation(
                                word_phrase=annotated_word,
                                annotation=annotation_type,
                                annotated_by=annotated_by,
                                annotated_on=datetime.datetime.strptime(annotated_on, "%Y-%m-%d"),
                                sentence_id=sentence.id,
                                project_id=new_project.id
                            )
                            db.session.add(annotation_record)
                    
                    sentence_counter += 1  # Increment for next sentence

        except ET.ParseError as e:
            db.session.rollback()
            print(f"XML Parsing Error: {str(e)}")  # Debugging
            return jsonify({'message': 'Invalid XML format'}), 400
        except Exception as e:
            db.session.rollback()
            print(f"Unexpected Error: {str(e)}")  # Debugging
            return jsonify({'message': f'An error occurred: {str(e)}'}), 500
    
    else:
        print("Detected Plain Text input.")  # Debugging

        # Check if text contains Manipuri characters
        if re.search(r'[\uABC0-\uABFF]', file_text):  # Manipuri Unicode range
            sentences = split_manipuri_sentences(file_text)
        else:
            # Fallback to standard sentence splitting for other languages
            sentences = split_sentences_with_lang(file_text, data.get("language"))

        for sentence_text in sentences:
            clean_text = sentence_text.strip()
            if clean_text:
                print(f"Saving Sentence {sentence_counter}: {clean_text}")

                sentence = Sentence(
                    sentence_number=sentence_counter,
                    content=clean_text,
                    is_annotated=False,
                    project_id=new_project.id
                )
                db.session.add(sentence)
                sentence_counter += 1
    
    db.session.commit()
    print("Project Successfully Created!")  # Debugging
    return new_project

def delete_project(project_id):
    project = Project.query.get(project_id)
    if not project:
        return {"error": "Project not found"}, 404

    try:
        # Delete annotations associated with each sentence in the project
        sentences = Sentence.query.filter_by(project_id=project_id).all()
        for sentence in sentences:
            # Delete annotations associated with the sentence
            Annotation.query.filter_by(sentence_id=sentence.id).delete()

        # Delete sentences associated with the project
        Sentence.query.filter_by(project_id=project_id).delete()

        # Finally, delete the project
        db.session.delete(project)
        db.session.commit()
        
        return {"message": "Project deleted successfully"}, 200

    except Exception as e:
        db.session.rollback()
        return {"error": str(e)}, 500




import re


def split_manipuri_sentences(text):
    # Manipuri-specific delimiters including Chakhei (꯫) and others
    delimiters = [
        '\uABEB',  # Manipuri Chakhei (꯫)
        '!',
        '\?',
        '।',       # Devanagari Danda
        '॥',       # Devanagari Double Danda
        '\n\n'     # Double newlines
    ]
    
    # Create regex pattern that matches any delimiter followed by optional whitespace
    pattern = '([' + ''.join(delimiters) + ']+\s*)'
    
    # Split text while keeping delimiters
    parts = re.split(pattern, text)
    
    sentences = []
    current_sentence = ''
    
    for part in parts:
        if not part.strip():
            continue
            
        # If part is a delimiter, finalize current sentence
        if re.fullmatch(pattern, part):
            if current_sentence:
                sentences.append(current_sentence.strip())
                current_sentence = ''
        else:
            current_sentence += part
    
    # Add any remaining text
    if current_sentence.strip():
        sentences.append(current_sentence.strip())
    
    return sentences

def get_projects_by_language(language):
    project = Project.query.filter_by(language=language).order_by(Project.id .desc()).all()
    return project


def get_projects():
    project = Project.query.filter_by().order_by(Project.id.desc()).all()
    return project



def get_projects_with_annotation_counts(user_language, organization=None):
    # Ensure user_language is always a list
    if isinstance(user_language, str):
        user_languages = [lang.strip() for lang in user_language.split(',')]
    elif isinstance(user_language, list):
        user_languages = [lang.strip() for lang in user_language]
    else:
        user_languages = []

    query = (
        db.session.query(
            Project,
            func.count(Sentence.id).label("total_sentences"),
            func.coalesce(
                func.sum(
                    case(
                        (Sentence.is_annotated == True, 1),
                        else_=0
                    )
                ),
                0
            ).label("completed_sentences")
        )
        .outerjoin(Sentence, Sentence.project_id == Project.id)
        .join(User, Project.uploaded_by == User.email)
        .filter(
            Project.language.in_(tuple(user_languages)) if user_languages else True
        )
        .group_by(Project.id)
    )

    if organization:
        query = query.filter(User.organisation == organization)

    projects = query.order_by(Project.id.desc()).all()

    return projects

def get_projects_with_annotation_counts_for_user(user_id):

    projects = (
        db.session.query(
            Project,
            func.count(Sentence.id).label("total_sentences"),
            func.coalesce(
                func.sum(
                    case(
                        (Sentence.is_completed == True, 1),
                        else_=0
                    )
                ),
                0
            ).label("completed_sentences")
        )
        .outerjoin(Sentence, Sentence.project_id == Project.id)
        .filter(Project.assigned_to == user_id)
        .group_by(Project.id)
        .order_by(Project.id.desc())
        .all()
    )

    return projects



def get_annotation_subquery():
    annotated_subquery = db.session.query(
        Sentence.project_id,
        func.count('*').label('annotated_count')
    ).filter_by(is_annotated=True).group_by(Sentence.project_id).subquery()

    # Subquery to count unannotated sentences for each project
    unannotated_subquery = db.session.query(
        Sentence.project_id,
        func.count('*').label('unannotated_count')
    ).filter_by(is_annotated=False).group_by(Sentence.project_id).subquery()
    return annotated_subquery, unannotated_subquery


def assign_user_to_project(project_id, user_id, force=False):
    project = Project.query.get(project_id)
    if not project:
        return {"error": "Project not found"}, 404

    user = User.query.get(user_id)
    if not user:
        return {"error": "User not found"}, 404

    # 🚨 Already assigned to someone else
    if project.is_assigned and project.assigned_to != user_id and not force:
        prev_user = User.query.get(project.assigned_to)
        return {
            "warning": True,
            "message": f"Project is already assigned to {prev_user.name}",
            "assigned_to": prev_user.id,
            "assigned_to_name": prev_user.name
        }, 409

    # ✅ Assign / Reassign
    project.assigned_to = user_id
    project.is_assigned = True
    db.session.commit()

    return {
        "message": f"Project assigned to {user.name}",
        "reassigned": force
    }, 200


def is_user_assigned_to_project(project_id):
    project = Project.query.get(project_id)
    if not project:
        return {"error": "Project not found"}, 404

    return {
        "is_assigned": project.is_assigned,
        "assigned_to": project.assigned_to
    }, 200


def update_project_title(project_id, new_title):
    # Fetch the project by ID
    project = Project.query.get(project_id)
    if not project:
        return {"error": "Project not found"}, 404

    # Update the title
    project.title = new_title

    try:
        db.session.commit()
        return {"message": "Project title updated successfully"}, 200
    except Exception as e:
        db.session.rollback()
        return {"error": str(e)}, 500


def send_assignment_email(user_email, user_name, project_title):
    """ Sends an email notification when a user is assigned to a project """
    subject = "Project Assignment Notification - MWE Annotation Workbench"
    body = f"""
    Hello {user_name},

    You have been assigned to the project "{project_title}" in the MWE Annotation Workbench.

    Please log in to your account to start working on the project.

    Regards,
    MWE Annotation Workbench Team
    """
    
    msg = Message(subject=subject, sender="mwa.iiith@gmail.com", recipients=[user_email])
    msg.body = body
    try:
        mail.send(msg)
        print(f"Email sent successfully to {user_email}")
    except Exception as e:
        print(f"Failed to send email: {e}")