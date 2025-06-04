def segment_manipuri_sentences(text):
    """
    Splits a Manipuri (Meitei Mayek) text into sentences using the Chakhei delimiter (꯫).
    """
    chakhei_delimiter = '\uABEB'  # Chakhei character
    sentences = [sentence.strip() for sentence in text.split(chakhei_delimiter) if sentence.strip()]
    return sentences

# Example usage
if __name__ == "__main__":
    manipuri_text = "ꯃꯤꯇꯩ ꯃꯌꯦꯛ ꯂꯩꯕꯥ ꯑꯁꯤꯡꯗꯤꯒꯤ ꯫ ꯄꯨꯔꯤ ꯄꯨꯝꯄꯤꯔ ꯍꯥꯡꯗꯤ ꯫"
    segmented_sentences = segment_manipuri_sentences(manipuri_text)
    
    for i, sentence in enumerate(segmented_sentences, 1):
        print(f"Sentence {i}: {sentence}")
