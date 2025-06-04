from app.models.sentence_model import Sentence
from flask_mail import Mail,Message

def get_sentences(data):
    project_id = data['project_id']
    sentences = Sentence.query.filter_by(project_id=project_id).order_by(Sentence.id).all()
    return sentences

def send_assignment_email(notification):
    subject = f"Assignment Notification: {notification['project_name']}"
    recipients = [notification['email']]
    assigned_sentences = ", ".join(map(str, notification['sentence_ids']))

    body = f"""
    Dear {notification['name']},

    You have been assigned the following sentences for the project **{notification['project_name']}**:

    Sentence IDs: {assigned_sentences}  
    Please complete them as soon as possible.

    Best regards,  
    Your Team
    """

    msg = Message(subject=subject, sender="mwa.iiith@gmail.com", recipients=recipients)  
    msg.body = body  

    try:
        Mail.send(msg)
        print(f"Email sent successfully to {notification['email']} for {notification['project_name']}")
    except Exception as e:
        print(f"Error sending email to {notification['email']}: {e}")
        

