import random
from .. import db, bcrypt , mail
from ..models.user_model import User
from ..models.sentence_model import Sentence
import jwt
import datetime
from flask import current_app
from flask_mail import Message



def create_user(data):
    # Check if email already exists
    existing_user = User.query.filter_by(email=data['email']).first()
    if existing_user:
        return {
            "success": False,
            "message": "Email already registered",
            "suggestion": "Try logging in or use a different email address"
        }

    # Check if username (name) already exists (optional)
    existing_name = User.query.filter_by(name=data['name']).first()
    if existing_name:
        return {
            "success": False,
            "message": "Username already taken",
            "suggestion": "Try adding numbers or initials to make it unique"
        }

    hashed_password = bcrypt.generate_password_hash(data['password']).decode('utf-8')

    # Ensure language is always a list before joining
    languages_list = data['language']

    if isinstance(languages_list, str):  # If a single string is passed, convert it to a list
        languages_list = [languages_list]

    languages_str = ",".join(languages_list)  # Store as "English,Hindi"

    new_user = User(
        name=data['name'],
        email=data['email'],
        password=hashed_password,
        language=languages_str,  # Stores correctly even for one language
        role=data['role'],
        organisation=data['organisation']
    )

    db.session.add(new_user)
    db.session.commit()
    
    return {
        "success": True,
        "user": new_user
    }

def check_user(email, password):
    user = User.query.filter_by(email=email).first()
    if user and bcrypt.check_password_hash(user.password, password):
        return user
    return None


def get_user_role(email):
    user = User.query.filter_by(email=email).first()
    return user.role

def get_user_id(id):
    user = User.query.filter_by(email=id).first()
    return user.id

def get_users_by_organisation(organisation):
    users = User.query.filter_by(organisation=organisation).filter(User.role != 'Admin').all()
    return users

def assign_sentences_custom(project_id, assignment_dict):
    """
    Assigns specific sentences from a project to users based on a custom distribution.

    :param project_id: ID of the project whose sentences are being assigned.
    :param assignment_dict: Dictionary {user_id: [sentence_id1, sentence_id2, ...]} defining sentence IDs for each user.
    :return: A message indicating success or failure.
    """
    # Fetch all unassigned sentences belonging to the given project
    available_sentences = {s.id: s for s in Sentence.query.filter_by(project_id=project_id, user_id=None).all()}
    
    # Collect all requested sentence IDs
    requested_sentence_ids = {sid for sids in assignment_dict.values() for sid in sids}
    
    # Check if all requested IDs exist and are unassigned
    invalid_ids = requested_sentence_ids - available_sentences.keys()
    if invalid_ids:
        return {"message": f"Invalid or already assigned sentence IDs: {list(invalid_ids)}"}

    # Assign sentences based on request
    for user_id, sentence_ids in assignment_dict.items():
        for sentence_id in sentence_ids:
            if sentence_id in available_sentences:
                available_sentences[sentence_id].user_id = user_id  # Assign to user

    db.session.commit()
    return {"message": f"Sentences for project {project_id} assigned successfully."}



otp_storage = {}

def generate_otp():
    return str(random.randint(100000, 999999))  # 6-digit OTP

def send_reset_otp(email):
    user = User.query.filter_by(email=email).first()
    if not user:
        return None  # User not found

    otp = generate_otp()
    otp_storage[email] = otp  # Store OTP temporarily

    # Customize the email content
    subject = "Password Reset OTP - MWE Annotation Tool"
    body = f"""
    Hello {user.name},  

    You have requested to reset your password for the **MWEnnotation Tool**.  
    Your OTP for password reset is: **{otp}**  

    Please enter this OTP in the app to verify your identity.  
    If you did not request this, please ignore this email.  

    Regards,  
    MWE Annotation Tool Support Team  
    """

    # Send OTP via Email
    msg = Message(subject, sender="noreply@nertool.com", recipients=[email])
    msg.body = body
    mail.send(msg)

    return True

def verify_otp(email, otp):
    return otp_storage.get(email) == otp  # Check OTP

def reset_password(email, new_password):
    user = User.query.filter_by(email=email).first()
    if user:
        hashed_password = bcrypt.generate_password_hash(new_password).decode('utf-8')
        user.password = hashed_password
        db.session.commit()
        return True
    return False

def get_user_language(email):
    user = User.query.filter_by(email=email).first()
    if not user:
        return None
    return user.language.split(",") if user.language else []  # Convert string back to list


def get_user_organisation(user_email):
    user = User.query.filter_by(email=user_email).first()
    return user.organisation if user else None


def update_user_profile(email, data):
    user = User.query.filter_by(email=email).first()
    if not user:
        return None  # User not found

    # Update only provided fields
    if 'name' in data:
        user.name = data['name']
    if 'new_email' in data:  # Changing email
        user.email = data['new_email']
    if 'language' in data:
        if isinstance(data['language'], list):  # Ensure it's a list before saving
            user.language = ",".join(data['language'])
        else:
            user.language = data['language']  # If already a string, store as is
    if 'role' in data:
        user.role = data['role']
    if 'organisation' in data:
        user.organisation = data['organisation']

    db.session.commit()
    return user


def get_user_details(email):
    user = User.query.filter_by(email=email).first()
    if not user:
        return None
    return {
        "id": user.id,
        "name": user.name,
        "email": user.email,
        "language": user.language.split(",") if user.language else [],  # Convert string back to list
        "role": user.role,
        "organisation": user.organisation,
        "registered_on": user.registered_on.strftime("%Y-%m-%d %H:%M:%S")
    }


def send_feedback_email(user_name, user_email, feedback_text):
    """
    Sends feedback email to sashank.tatavolu@research.iiit.ac.in
    """
    try:
        subject = "New Feedback Submission"
        body = f"""
        Hello Sashank,

        You have received a new feedback submission.

        User Name: {user_name}
        User Email: {user_email}

        Feedback:
        {feedback_text}

        Regards,
        MWE Annotation Tool
        """

        msg = Message(subject, sender="noreply@nertool.com", recipients=["sashank.tatavolu@research.iiit.ac.in"])
        msg.body = body
        mail.send(msg)

        return True
    except Exception as e:
        print("Error sending feedback email:", e)
        return False