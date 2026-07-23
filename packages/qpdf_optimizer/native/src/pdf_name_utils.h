#ifndef PDF_NAME_UTILS_H
#define PDF_NAME_UTILS_H

#include <cstdint>
#include <string>
#include <vector>

#include <qpdf/QPDFObjectHandle.hh>

inline std::string normalizePdfName(std::string value)
{
    if (!value.empty() && value.front() == '/') {
        value.erase(value.begin());
    }
    return value;
}

inline std::string pdfName(QPDFObjectHandle const& object)
{
    return object.isName() ? normalizePdfName(object.getName()) : std::string();
}

inline std::string pdfDictionaryKey(std::string value)
{
    if (value.empty() || value.front() != '/') {
        value.insert(value.begin(), '/');
    }
    return value;
}

inline uint64_t pdfObjectKey(int32_t object_number, int32_t generation)
{
    return (static_cast<uint64_t>(static_cast<uint32_t>(object_number)) << 32) |
           static_cast<uint32_t>(generation);
}

inline uint64_t pdfObjectKey(QPDFObjectHandle const& object)
{
    return object.isIndirect()
        ? pdfObjectKey(object.getObjectID(), object.getGeneration())
        : 0;
}

struct PdfFilterInfo {
    std::string terminal;
    bool supported;
    bool generalized_wrappers;

    PdfFilterInfo()
        : supported(false), generalized_wrappers(false) {}
};

inline bool isGeneralizedPdfFilter(std::string const& name)
{
    return name == "ASCIIHexDecode" || name == "AHx" ||
           name == "ASCII85Decode" || name == "A85" ||
           name == "LZWDecode" || name == "LZW" ||
           name == "FlateDecode" || name == "Fl";
}

inline PdfFilterInfo imageFilterInfo(QPDFObjectHandle filter)
{
    PdfFilterInfo info;
    if (filter.isNull()) {
        info.supported = true;
        return info;
    }

    std::vector<std::string> names;
    if (filter.isName()) {
        names.push_back(pdfName(filter));
    } else if (filter.isArray()) {
        auto count = filter.getArrayNItems();
        for (decltype(count) i = 0; i < count; ++i) {
            auto item = filter.getArrayItem(i);
            if (!item.isName()) {
                return info;
            }
            names.push_back(pdfName(item));
        }
    } else {
        return info;
    }

    if (names.empty()) {
        info.supported = true;
        return info;
    }

    info.terminal = names.back();
    if (names.size() == 1) {
        if (info.terminal == "DCT") {
            info.terminal = "DCTDecode";
        } else if (info.terminal == "Fl") {
            info.terminal = "FlateDecode";
        }
        info.supported =
            info.terminal == "DCTDecode" ||
            info.terminal == "FlateDecode";
        return info;
    }

    if (info.terminal != "DCTDecode" && info.terminal != "DCT") {
        return info;
    }

    for (size_t i = 0; i + 1 < names.size(); ++i) {
        if (!isGeneralizedPdfFilter(names[i])) {
            return info;
        }
    }

    info.terminal = "DCTDecode";
    info.supported = true;
    info.generalized_wrappers = true;
    return info;
}

inline std::string singlePdfFilterName(QPDFObjectHandle filter)
{
    auto info = imageFilterInfo(filter);
    return info.supported ? info.terminal : "UnsupportedFilterChain";
}

#endif
