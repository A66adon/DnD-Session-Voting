package ds.dnd.voting.services;

import ds.dnd.voting.dto.TimeSlotStatsDTO;
import ds.dnd.voting.dto.VoteResultDTO;
import ds.dnd.voting.dto.WeekResultDTO;
import ds.dnd.voting.model.TimeSlot;
import ds.dnd.voting.model.Vote;
import ds.dnd.voting.model.VotingWeek;
import ds.dnd.voting.repositories.TimeSlotRepository;
import ds.dnd.voting.repositories.VoteRepository;
import ds.dnd.voting.repositories.VotingWeekRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.time.temporal.TemporalAdjusters;
import java.util.*;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class VotingService {

    private final VotingWeekRepository votingWeekRepository;
    private final TimeSlotRepository timeSlotRepository;
    private final VoteRepository voteRepository;

    /**
     * Get the current active voting week
     */
    public VotingWeek getCurrentWeek() {
        return votingWeekRepository.findCurrentWeek(LocalDate.now())
                .orElseGet(this::createNewWeek);
    }

    /**
     * Get detailed results for a specific week including who voted for what
     */
    @Transactional(readOnly = true)
    public WeekResultDTO getWeekResults(Long weekId) {
        VotingWeek week = votingWeekRepository.findById(weekId)
                .orElseThrow(() -> new RuntimeException("Week not found"));

        List<Vote> votes = voteRepository.findVotesByVotingWeek(weekId);

        // Create vote results showing who voted for what
        List<VoteResultDTO> voteResults = votes.stream()
                .map(vote -> new VoteResultDTO(
                        vote.getVoterName(),
                        vote.getTimeslots().stream()
                                .map(TimeSlot::getDatetime)
                                .sorted()
                                .collect(Collectors.toList())
                ))
                .collect(Collectors.toList());

        // Calculate statistics for each timeslot
        List<TimeSlotStatsDTO> timeSlotStats = week.getTimeSlots().stream()
                .map(timeSlot -> {
                    Long voteCount = timeSlotRepository.countVotesByTimeSlotId(timeSlot.getId());
                    return new TimeSlotStatsDTO(
                            timeSlot.getId(),
                            timeSlot.getDatetime(),
                            voteCount.intValue(),
                            false // Will be set later for winner
                    );
                })
                .sorted(Comparator.comparing(TimeSlotStatsDTO::getDatetime))
                .collect(Collectors.toList());

        // Determine winner (timeslot with most votes)
        TimeSlotStatsDTO winner = timeSlotStats.stream()
                .max(Comparator.comparing(TimeSlotStatsDTO::getVoteCount))
                .orElse(null);

        if (winner != null) {
            winner.setWinner(true);
        }

        WeekResultDTO result = new WeekResultDTO();
        result.setWeekId(week.getId());
        result.setDeadline(week.getDeadline());
        result.setTimeSlots(timeSlotStats);
        result.setVotes(voteResults);
        result.setWinnerTimeSlot(winner);

        return result;
    }

    /**
     * Get results for the current active week
     */
    @Transactional(readOnly = true)
    public WeekResultDTO getCurrentWeekResults() {
        VotingWeek currentWeek = getCurrentWeek();

        List<Vote> votes = voteRepository.findVotesByVotingWeek(currentWeek.getId());

        // Create vote results showing who voted for what
        List<VoteResultDTO> voteResults = votes.stream()
                .map(vote -> new VoteResultDTO(
                        vote.getVoterName(),
                        vote.getTimeslots().stream()
                                .map(TimeSlot::getDatetime)
                                .sorted()
                                .collect(Collectors.toList())
                ))
                .collect(Collectors.toList());

        // Calculate statistics for each timeslot
        List<TimeSlotStatsDTO> timeSlotStats = currentWeek.getTimeSlots().stream()
                .map(timeSlot -> {
                    Long voteCount = timeSlotRepository.countVotesByTimeSlotId(timeSlot.getId());
                    return new TimeSlotStatsDTO(
                            timeSlot.getId(),
                            timeSlot.getDatetime(),
                            voteCount.intValue(),
                            false // Will be set later for winner
                    );
                })
                .sorted(Comparator.comparing(TimeSlotStatsDTO::getDatetime))
                .collect(Collectors.toList());

        // Determine winner (timeslot with most votes)
        TimeSlotStatsDTO winner = timeSlotStats.stream()
                .max(Comparator.comparing(TimeSlotStatsDTO::getVoteCount))
                .orElse(null);

        if (winner != null) {
            winner.setWinner(true);
        }

        WeekResultDTO result = new WeekResultDTO();
        result.setWeekId(currentWeek.getId());
        result.setDeadline(currentWeek.getDeadline());
        result.setTimeSlots(timeSlotStats);
        result.setVotes(voteResults);
        result.setWinnerTimeSlot(winner);

        return result;
    }

    /**
     * Get all past weeks with their results
     */
    @Transactional(readOnly = true)
    public List<WeekResultDTO> getAllPastWeeks() {
        List<VotingWeek> allWeeks = votingWeekRepository.findAllByOrderByDeadlineDesc();

        return allWeeks.stream()
                .filter(week -> week.getDeadline().isBefore(LocalDate.now()))
                .map(week -> getWeekResults(week.getId()))
                .collect(Collectors.toList());
    }

    /**
     * Get all weeks including current
     */
    @Transactional(readOnly = true)
    public List<WeekResultDTO> getAllWeeks() {
        List<VotingWeek> allWeeks = votingWeekRepository.findAllByOrderByDeadlineDesc();

        return allWeeks.stream()
                .map(week -> getWeekResults(week.getId()))
                .collect(Collectors.toList());
    }

    /**
     * Manually trigger a week reset (useful for testing)
     */
    @Transactional
    public VotingWeek resetWeek() {
        log.info("Manually triggering week reset");
        return createNewWeek();
    }
    /**
     * Scheduled task to reset the voting week every Monday at midnight
     */
    @Scheduled(cron = "0 0 0 * * MON", zone = "Europe/Berlin")
    @Transactional
    public void scheduledWeekReset() {
        log.info("Scheduled week reset triggered at {}", LocalDateTime.now());
        createNewWeek();
    }

    /**
     * Create a new voting week with fresh timeslots
     */
    @Transactional
    protected VotingWeek createNewWeek() {
        LocalDate today = LocalDate.now();

        // Calculate deadline: next Sunday
        LocalDate nextSunday = today.with(TemporalAdjusters.next(DayOfWeek.SUNDAY));

        // Create new voting week
        VotingWeek newWeek = new VotingWeek();
        newWeek.setDeadline(nextSunday);
        newWeek.setTimeSlots(new ArrayList<>());

        VotingWeek savedWeek = votingWeekRepository.save(newWeek);

        // Generate timeslots for the upcoming week (Monday to Sunday after deadline)
        List<TimeSlot> timeSlots = generateTimeSlots(nextSunday, savedWeek);
        timeSlotRepository.saveAll(timeSlots);

        savedWeek.getTimeSlots().addAll(timeSlots);

        log.info("Created new voting week with ID {} and deadline {}", savedWeek.getId(), nextSunday);

        return savedWeek;
    }

    /**
     * Generate timeslots for the week following the deadline
     * Creates slots for each day of the week at common gaming times
     */
    private List<TimeSlot> generateTimeSlots(LocalDate deadline, VotingWeek votingWeek) {
        List<TimeSlot> timeSlots = new ArrayList<>();

        // Start from Monday after the deadline
        LocalDate startDate = deadline.plusDays(1); // Monday after Sunday deadline

        // Common D&D session times (you can customize these)
        List<LocalTime> sessionTimes = Arrays.asList(
                LocalTime.of(18, 0),  // 6 PM
                LocalTime.of(19, 0),  // 7 PM
                LocalTime.of(20, 0)   // 8 PM
        );

        // Generate slots for 7 days (Monday to Sunday)
        for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
            LocalDate date = startDate.plusDays(dayOffset);

            for (LocalTime time : sessionTimes) {
                LocalDateTime slotDateTime = LocalDateTime.of(date, time);
                TimeSlot timeSlot = new TimeSlot(slotDateTime, votingWeek);
                timeSlots.add(timeSlot);
            }
        }

        log.info("Generated {} timeslots for week starting {}", timeSlots.size(), startDate);

        return timeSlots;
    }

    /**
     * Submit a vote for the current week
     * If the user has already voted, the existing vote will be updated
     */
    @Transactional
    public Vote submitVote(String voterName, List<Long> timeSlotIds) {
        VotingWeek currentWeek = getCurrentWeek();

        // Verify all timeslots belong to current week
        List<TimeSlot> timeSlots = timeSlotRepository.findAllById(timeSlotIds);

        boolean allBelongToCurrentWeek = timeSlots.stream()
                .allMatch(ts -> ts.getVotingWeek().getId().equals(currentWeek.getId()));

        if (!allBelongToCurrentWeek) {
            throw new RuntimeException("Some timeslots do not belong to the current voting week");
        }

        // Check if user has already voted for this week
        Optional<Vote> existingVote = voteRepository.findByVoterNameAndVotingWeek(voterName, currentWeek.getId());

        Vote vote;
        if (existingVote.isPresent()) {
            // Update existing vote
            vote = existingVote.get();
            vote.getTimeslots().clear();
            vote.getTimeslots().addAll(timeSlots);
            log.info("Updated vote for {} with {} timeslots", voterName, timeSlotIds.size());
        } else {
            // Create new vote
            vote = new Vote(voterName, timeSlots);
            log.info("Created new vote for {} with {} timeslots", voterName, timeSlotIds.size());
        }

        return voteRepository.save(vote);
    }

}
