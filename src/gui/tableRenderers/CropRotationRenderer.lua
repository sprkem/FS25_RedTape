RTCropRotationRenderer = {}
RTCropRotationRenderer_mt = Class(RTCropRotationRenderer)

function RTCropRotationRenderer.new()
    local self = {}
    setmetatable(self, RTCropRotationRenderer_mt)
    self.data = nil
    self.selectedRow = -1;

    return self
end

function RTCropRotationRenderer:setData(data)
    self.data = data
end

function RTCropRotationRenderer:getNumberOfSections()
    return 1
end

function RTCropRotationRenderer:getNumberOfItemsInSection(list, section)
    return #self.data
end

function RTCropRotationRenderer:getTitleForSectionHeader(list, section)
    return ""
end

function RTCropRotationRenderer:populateCellForItemInSection(list, section, index, cell)
    local data = self.data[index]

    cell:getAttribute("farmland"):setText(data.farmland)
    cell:getAttribute("fruitName5"):setText(data.fruitName5)
    cell:getAttribute("fruitName4"):setText(data.fruitName4)
    cell:getAttribute("fruitName3"):setText(data.fruitName3)
    cell:getAttribute("fruitName2"):setText(data.fruitName2)
    cell:getAttribute("fruitName1"):setText(data.fruitName1)

    if data.fruitIcon5 ~= nil and data.fruitIcon5 ~= "" then
        cell:getAttribute("fruitIcon5"):setImageFilename(data.fruitIcon5)
        cell:getAttribute("fruitIcon5"):setVisible(true)
    else
        cell:getAttribute("fruitIcon5"):setVisible(false)
    end

    if data.fruitIcon4 ~= nil and data.fruitIcon4 ~= "" then
        cell:getAttribute("fruitIcon4"):setImageFilename(data.fruitIcon4)
        cell:getAttribute("fruitIcon4"):setVisible(true)
    else
        cell:getAttribute("fruitIcon4"):setVisible(false)
    end

    if data.fruitIcon3 ~= nil and data.fruitIcon3 ~= "" then
        cell:getAttribute("fruitIcon3"):setImageFilename(data.fruitIcon3)
        cell:getAttribute("fruitIcon3"):setVisible(true)
    else
        cell:getAttribute("fruitIcon3"):setVisible(false)
    end

    if data.fruitIcon2 ~= nil and data.fruitIcon2 ~= "" then
        cell:getAttribute("fruitIcon2"):setImageFilename(data.fruitIcon2)
        cell:getAttribute("fruitIcon2"):setVisible(true)
    else
        cell:getAttribute("fruitIcon2"):setVisible(false)
    end

    if data.fruitIcon1 ~= nil and data.fruitIcon1 ~= "" then
        cell:getAttribute("fruitIcon1"):setImageFilename(data.fruitIcon1)
        cell:getAttribute("fruitIcon1"):setVisible(true)
    else
        cell:getAttribute("fruitIcon1"):setVisible(false)
    end
end
