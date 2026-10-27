#include "VNTextRecognizerCore.hpp"

#include <tesseract/baseapi.h>
#include <tesseract/resultiterator.h>

#include <cstring>
#include <mutex>

namespace {

std::mutex engineMutex;
tesseract::TessBaseAPI *engine = nullptr;
std::string engineKey;

const char *const dictionaries[] = {"load_system_dawg", "load_freq_dawg", "load_punc_dawg", "load_number_dawg",
                                    "load_unambig_dawg", "load_bigram_dawg", "load_fixed_length_dawgs"};

bool prepare(const RevenantTextRequest& request, std::string& error)
{
    std::string key = request.datapath + '\n' + request.language + '\n' + request.userWordsFile + '\n' +
                      (request.correction ? '1' : '0');
    if (engine != nullptr && key == engineKey)
        return true;
    delete engine;
    engine = nullptr;
    tesseract::TessBaseAPI *api = new tesseract::TessBaseAPI();
    if (!request.correction) {
        for (const char *dictionary : dictionaries)
            api->SetVariable(dictionary, "F");
    }
    if (!request.userWordsFile.empty())
        api->SetVariable("user_words_file", request.userWordsFile.c_str());
    if (api->Init(request.datapath.c_str(), request.language.c_str(), tesseract::OEM_LSTM_ONLY) != 0) {
        delete api;
        error = "the recognition model in " + request.datapath + " could not be loaded";
        return false;
    }
    api->SetPageSegMode(tesseract::PSM_AUTO);
    engine = api;
    engineKey = key;
    return true;
}

void moveBy(int& left, int& top, int& right, int& bottom, const RevenantTextRequest& request)
{
    left += request.regionLeft;
    right += request.regionLeft;
    top += request.regionTop;
    bottom += request.regionTop;
}

std::string trimmed(char *text)
{
    std::string value = text != nullptr ? text : "";
    delete[] text;
    while (!value.empty() && (value.back() == ' ' || value.back() == '\n' || value.back() == '\t' || value.back() == '\r'))
        value.pop_back();
    return value;
}

}

bool RevenantTextRecognize(const uint8_t *gray, int width, int height, const RevenantTextRequest& request,
                           std::vector<RevenantTextLine>& lines, std::string& error)
{
    std::lock_guard<std::mutex> lock(engineMutex);
    lines.clear();
    if (!prepare(request, error))
        return false;
    std::vector<uint8_t> crop((size_t)request.regionWidth * (size_t)request.regionHeight);
    for (int row = 0; row < request.regionHeight; ++row)
        std::memcpy(crop.data() + (size_t)row * (size_t)request.regionWidth,
                    gray + (size_t)(request.regionTop + row) * (size_t)width + (size_t)request.regionLeft, (size_t)request.regionWidth);
    engine->SetImage(crop.data(), request.regionWidth, request.regionHeight, 1, request.regionWidth);
    if (engine->Recognize(nullptr) != 0) {
        error = "the text could not be recognized";
        return false;
    }
    tesseract::ResultIterator *iterator = engine->GetIterator();
    if (iterator != nullptr) {
        do {
            if (iterator->IsAtBeginningOf(tesseract::RIL_TEXTLINE)) {
                RevenantTextLine line{};
                iterator->BoundingBox(tesseract::RIL_TEXTLINE, &line.left, &line.top, &line.right, &line.bottom);
                moveBy(line.left, line.top, line.right, line.bottom, request);
                line.text = trimmed(iterator->GetUTF8Text(tesseract::RIL_TEXTLINE));
                lines.push_back(line);
            }
            if (lines.empty() || iterator->Empty(tesseract::RIL_WORD))
                continue;
            RevenantTextWord word{};
            word.text = trimmed(iterator->GetUTF8Text(tesseract::RIL_WORD));
            word.confidence = iterator->Confidence(tesseract::RIL_WORD);
            iterator->BoundingBox(tesseract::RIL_WORD, &word.left, &word.top, &word.right, &word.bottom);
            moveBy(word.left, word.top, word.right, word.bottom, request);
            if (word.text.empty())
                continue;
            RevenantTextLine& current = lines.back();
            current.confidence += word.confidence;
            current.words.push_back(word);
        } while (iterator->Next(tesseract::RIL_WORD));
        delete iterator;
    }
    std::vector<RevenantTextLine> recognized;
    for (RevenantTextLine& line : lines) {
        if (line.words.empty())
            continue;
        line.confidence /= 100.0f * (float)line.words.size();
        recognized.push_back(line);
    }
    lines.swap(recognized);
    return true;
}
